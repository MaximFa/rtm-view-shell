#!/usr/bin/env python3
"""
lint_metrics.py - RTSGrid_Metric catalogue validator

Validates db/data/02_metrics.sql against the RTM engine function inventory.
Detects: misspelled MetricFunction, broken Calc references, duplicates, hygiene issues,
catalogue field completeness.

Usage: python3 tools/lint_metrics.py [--sql PATH] [--rtm PATH]

Exit codes: 0 = clean/warnings only, 1 = errors found
"""

import argparse
import re
import sys
import os
from collections import defaultdict
from pathlib import Path

# --------------------------------------------------------------------------
# Engine function inventory (parsed from Union.cs and UserManager.cs)
# --------------------------------------------------------------------------

DATA_FUNCS = {
    "NumWaitings", "WaitDurationCurMax", "AnsweredCount", "AbandonedCount",
    "AnsweredPercent", "AbandonedPercent", "InteractionsCount", "CPH",
    "MessagesCount", "MessagesInteractionsCount", "MessagesPercent",
    "MessagesInteractionsPercent", "MessagesMaxFirstResponseTime",
    "MessagesAvgFirstResponseTime", "MessagesAvgResponseTime",
    "WaitDurationAvg", "WaitDurationMax", "TalkDurationAvg",
    "TalkDurationTotal", "TalkDurationMax", "TalkDurationCurMax",
    "LogedInUsersCount", "UsersInStatusCount", "UsersInStatusGroupCount",
    "UsersInStatusPercent", "UsersInStatusGroupPercent",
    "UsersInStatusDurationAvg", "UsersInStatusGroupDurationAvg",
    "UsersInStatusDurationPercent", "UsersInStatusGroupDurationPercent",
    "UsersInStatusDurationCurMax", "UsersInStatusGroupDurationCurMax",
    "UsersInStatusDurationMax", "UsersInStatusGroupDurationMax",
    "Calc",
}

AGENT_FUNCS = {
    "UserID", "FirstName", "LastName", "DisplayName", "UserExtension",
    "Station", "OnPhoneDuration", "UserCustomAttribute", "IsTodayLogin",
    "CurLoginDuration", "CurLoginDurationReal", "CurLoginTimestamp",
    "FirstLoginTimestamp", "CurStatus", "CurStatusTitle", "CurStatusGroup",
    "CurStatusDuration", "CurStatusGroupDuration", "CalculatedStatus",
    "CalculatedStatusTime", "TotalLoginDuration", "TotalStatusDuration",
    "TotalStatusGroupDuration", "TotalStatusPercent", "TotalStatusGroupPercent",
    "TotalStatusCount", "TotalStatusGroupCount", "TotalStatusDurationAvg",
    "TotalStatusGroupDurationAvg", "TotalStatusDurationMax",
    "TotalStatusGroupDurationMax", "LongestInteractionId",
    "LongestInteractionWorkgroup", "LongestInteractionType",
    "LongestInteractionRemoteAddress", "LongestInteractionCustomCallData",
    "LongestInteractionDuration", "LongestInteractionState",
    "LongestInteractionStateDuration", "InteractionsCount", "CPH",
    "TalkDurationAvg", "TalkDurationMax", "Productivity", "Efficiency",
    "MessagesAvgFirstResponseTime", "MessagesAvgResponseTime", "Calc",
}

# IDInteraction properties (for string-literal check)
INTERACTION_PROPS = {
    "InteractionId", "Segment", "Workgroup", "State", "ChatStats",
    "LastWorkgroup", "ClassificationCode", "InteractionType", "CallType",
    "Direction", "CustomCallData", "RemoteAddress", "UserId", "LastUserId",
    "IsTransferred", "IsAnswered", "IsAbandoned", "IsMessaging", "IsInQueue",
    "IsTalk", "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime",
    "DisconnectDateTime", "InQueueLocalDateTime", "AnsweredLocalDateTime",
    "DisconnectLocalDateTime", "LastMessageSid", "IsCallbackRequest",
    "IsHeldChanged", "TimeZone", "IsDisconnected",
}
# Add CustomCallData1..20
for i in range(1, 21):
    INTERACTION_PROPS.add(f"CustomCallData{i}")

# ChatMessage properties
CHATMESSAGE_PROPS = {
    "MessageId", "MsgDirection", "Sender", "Recipient", "Body",
    "DeliveryStatus", "InteractionId", "SegmentId", "UserId", "TimeStamp",
}

ALL_PROPS = INTERACTION_PROPS | CHATMESSAGE_PROPS

# Known defects pending separate fix (D3 - EF-based migration)
KNOWN_DEFECTS = {
    "MonAgentCurrentLoginTimeStamp",  # CurLoginTimeStamp vs CurLoginTimestamp (case mismatch)
}

# Status counter functions that ignore bag for duplicate detection
STATUS_COUNTER_FUNCS = {
    "UsersInStatusCount", "UsersInStatusGroupCount", "LogedInUsersCount",
}

# Valid enum values
VALID_VALUE_TYPES = {"number", "time", "text"}
VALID_METRIC_TYPES = {"Data", "Agent"}
VALID_DATA_TYPES = {"Interactions Summary", "UsersInteraction", "UsersSummary", "User"}
VALID_CATALOG_STATUSES = {"active", "duplicate", "deprecated", "defect-candidate"}

# Column indices for the 21-column format (post-catalogue migration)
# Column order: MetricId(0), Description(1), DataType(2), MetricFunction(3),
# MetricParameter(4), MetricFormat(5), DefaultValue(6), ValueType(7), MetricType(8),
# CatalogCategory(9), CatalogNotes(10), CatalogStatus(11), Channel(12), Comparison(13),
# DisplayName(14), Family(15), LongDescription(16), ShortDescription(17),
# StandardKpi(18), StandardRef(19), ThresholdSec(20)
COL_METRIC_ID = 0
COL_DESCRIPTION = 1
COL_DATA_TYPE = 2
COL_METRIC_FUNCTION = 3
COL_METRIC_PARAMETER = 4
COL_METRIC_FORMAT = 5
COL_DEFAULT_VALUE = 6
COL_VALUE_TYPE = 7
COL_METRIC_TYPE = 8
COL_CATALOG_CATEGORY = 9
COL_CATALOG_NOTES = 10
COL_CATALOG_STATUS = 11
COL_CHANNEL = 12
COL_COMPARISON = 13
COL_DISPLAY_NAME = 14
COL_FAMILY = 15
COL_LONG_DESCRIPTION = 16
COL_SHORT_DESCRIPTION = 17
COL_STANDARD_KPI = 18
COL_STANDARD_REF = 19
COL_THRESHOLD_SEC = 20

# Support both 9-column (legacy) and 21-column (post-catalogue) formats
LEGACY_COLUMN_COUNT = 9
FULL_COLUMN_COUNT = 21


def parse_sql_copy(sql_path: Path) -> tuple[list[dict], int]:
    """Parse the COPY block from 02_metrics.sql. Returns (metrics, column_count)."""
    metrics = []
    in_copy = False
    detected_columns = 0

    with open(sql_path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.rstrip("\r\n")

            if line.startswith("COPY \"RTSGrid_Metric\""):
                in_copy = True
                continue

            if in_copy:
                if line == "\\.":
                    break

                parts = line.split("\t")
                if not detected_columns:
                    detected_columns = len(parts)

                # Build metric dict with all available columns
                m = {
                    "line_no": line_no,
                    "raw": line,
                    "parts": parts,
                    "metric_id": parts[COL_METRIC_ID] if len(parts) > COL_METRIC_ID else "",
                    "description": parts[COL_DESCRIPTION] if len(parts) > COL_DESCRIPTION else "",
                    "data_type": parts[COL_DATA_TYPE] if len(parts) > COL_DATA_TYPE else "",
                    "metric_function": parts[COL_METRIC_FUNCTION] if len(parts) > COL_METRIC_FUNCTION else "",
                    "metric_parameter": parts[COL_METRIC_PARAMETER] if len(parts) > COL_METRIC_PARAMETER else "",
                    "metric_format": parts[COL_METRIC_FORMAT] if len(parts) > COL_METRIC_FORMAT else "",
                    "default_value": parts[COL_DEFAULT_VALUE] if len(parts) > COL_DEFAULT_VALUE else "",
                    "value_type": parts[COL_VALUE_TYPE] if len(parts) > COL_VALUE_TYPE else "",
                    "metric_type": parts[COL_METRIC_TYPE] if len(parts) > COL_METRIC_TYPE else "",
                }

                # Add catalogue columns if present (21-column format)
                if len(parts) >= FULL_COLUMN_COUNT:
                    m["catalog_category"] = parts[COL_CATALOG_CATEGORY]
                    m["catalog_notes"] = parts[COL_CATALOG_NOTES]
                    m["catalog_status"] = parts[COL_CATALOG_STATUS]
                    m["channel"] = parts[COL_CHANNEL]
                    m["comparison"] = parts[COL_COMPARISON]
                    m["display_name"] = parts[COL_DISPLAY_NAME]
                    m["family"] = parts[COL_FAMILY]
                    m["long_description"] = parts[COL_LONG_DESCRIPTION]
                    m["short_description"] = parts[COL_SHORT_DESCRIPTION]
                    m["standard_kpi"] = parts[COL_STANDARD_KPI]
                    m["standard_ref"] = parts[COL_STANDARD_REF]
                    m["threshold_sec"] = parts[COL_THRESHOLD_SEC]

                metrics.append(m)

    return metrics, detected_columns


def canonical_param(param: str) -> str:
    """Normalize MetricParameter for duplicate detection"""
    if not param or param == "\\N":
        return ""
    # Trim, collapse whitespace
    s = " ".join(param.split())
    # Split on && at top level (simplified - doesn't handle nested parens)
    atoms = [a.strip() for a in s.split("&&")]
    # Strip redundant outer parens from each atom
    cleaned = []
    for atom in atoms:
        while atom.startswith("(") and atom.endswith(")"):
            inner = atom[1:-1]
            # Only strip if balanced
            if inner.count("(") == inner.count(")"):
                atom = inner.strip()
            else:
                break
        cleaned.append(atom)
    # Sort atoms for canonical form
    cleaned.sort()
    return "&&".join(cleaned)


def get_bag(data_type: str, metric_function: str, metric_type: str) -> str:
    """Determine bag for duplicate detection.

    MetricType=Agent metrics are in a separate scope from MetricType=Data metrics,
    even when they share the same MetricFunction.
    """
    if metric_function in STATUS_COUNTER_FUNCS:
        return "IGNORED"
    # Agent metrics are a separate scope
    if metric_type == "Agent":
        return "Agent"
    if data_type == "UsersInteraction":
        return "UsersInteraction"
    return "Data"


def is_null(val: str) -> bool:
    """Check if value is NULL or empty"""
    return not val or val == "\\N"


class Linter:
    def __init__(self, sql_path: Path, rtm_path: Path, ignore_known: bool = False):
        self.sql_path = sql_path
        self.rtm_path = rtm_path
        self.ignore_known = ignore_known
        self.errors = []
        self.warnings = []
        self.metrics = []
        self.metric_ids = set()
        self.column_count = 0

    def error(self, line_no: int, metric_id: str, msg: str):
        self.errors.append(f"ERROR L{line_no} [{metric_id}]: {msg}")

    def warn(self, line_no: int, metric_id: str, msg: str):
        self.warnings.append(f"WARN  L{line_no} [{metric_id}]: {msg}")

    def run(self) -> int:
        self.metrics, self.column_count = parse_sql_copy(self.sql_path)

        print(f"Detected {self.column_count} columns per row")

        # Build MetricId set for Calc ref validation
        for m in self.metrics:
            if m["metric_id"] and m["metric_id"] != "\\N":
                self.metric_ids.add(m["metric_id"])

        # Track seen keys for duplicate detection
        seen_keys = defaultdict(list)

        for m in self.metrics:
            self.check_column_count(m)
            self.check_metric_function(m)
            self.check_calc_refs(m)
            self.check_string_literal_props(m)
            self.check_metric_id_hygiene(m)
            self.check_enum_values(m)
            self.check_description_prefix(m)
            self.check_catalog_completeness(m)
            self.check_catalog_status(m)

            # Duplicate detection
            if m["metric_id"]:
                key = (
                    m["metric_function"],
                    canonical_param(m["metric_parameter"]),
                    get_bag(m["data_type"], m["metric_function"], m["metric_type"]),
                )
                seen_keys[key].append(m)

        # Check for duplicates
        for key, items in seen_keys.items():
            if len(items) > 1:
                ids = [i["metric_id"] for i in items]
                for item in items:
                    self.error(
                        item["line_no"],
                        item["metric_id"],
                        f"Duplicate key with {[x for x in ids if x != item['metric_id']]}"
                    )

        # Print results
        for e in self.errors:
            print(e)
        for w in self.warnings:
            print(w)

        print(f"\n{len(self.errors)} errors, {len(self.warnings)} warnings")

        return 1 if self.errors else 0

    def check_column_count(self, m: dict):
        """Check 1: Column count must be 9 (legacy) or 21 (post-catalogue)"""
        n = len(m["parts"])
        if n not in (LEGACY_COLUMN_COUNT, FULL_COLUMN_COUNT):
            self.error(m["line_no"], m["metric_id"],
                       f"Column count {n} not in [{LEGACY_COLUMN_COUNT}, {FULL_COLUMN_COUNT}]")

    def check_metric_function(self, m: dict):
        """Check 2: MetricFunction exists in engine (case-sensitive)"""
        func = m["metric_function"]
        if not func or func == "\\N":
            return

        mid = m["metric_id"]
        metric_type = m["metric_type"]

        # Skip known defects if flag set
        if self.ignore_known and mid in KNOWN_DEFECTS:
            self.warn(m["line_no"], mid, f"KNOWN DEFECT (skipped): MetricFunction case mismatch")
            return

        if metric_type == "Agent":
            if func not in AGENT_FUNCS:
                self.error(m["line_no"], m["metric_id"],
                           f"MetricFunction '{func}' not in AGENT_FUNCS (case-sensitive)")
        else:  # Data
            if func not in DATA_FUNCS:
                self.error(m["line_no"], m["metric_id"],
                           f"MetricFunction '{func}' not in DATA_FUNCS (case-sensitive)")

    def check_calc_refs(self, m: dict):
        """Check 3: Calc references must exist and have no whitespace"""
        if m["metric_function"] != "Calc":
            return

        param = m["metric_parameter"]
        if not param or param == "\\N":
            return

        # Find all [RefId] patterns
        for match in re.finditer(r'\[(.*?)\]', param):
            raw_ref = match.group(1)
            trimmed = raw_ref.strip()

            # Check for whitespace inside brackets
            if raw_ref != trimmed:
                self.error(m["line_no"], m["metric_id"],
                           f"Bracket ref '[{raw_ref}]' has leading/trailing whitespace")

            # Check if ref exists
            if trimmed and trimmed not in self.metric_ids:
                self.error(m["line_no"], m["metric_id"],
                           f"Calc references unknown MetricId: [{trimmed}]")

    def check_string_literal_props(self, m: dict):
        """Check 4: Property names in double-quoted strings (Roslyn gotcha)"""
        func = m["metric_function"]
        param = m["metric_parameter"]

        # Skip Calc, status counters, empty param
        if func == "Calc" or func in STATUS_COUNTER_FUNCS:
            return
        if not param or param == "\\N":
            return

        # Find double-quoted strings
        for match in re.finditer(r'"([^"]*)"', param):
            literal = match.group(1)
            # Check if any property name appears in the literal
            for prop in ALL_PROPS:
                if re.search(rf'\b{prop}\b', literal):
                    self.error(m["line_no"], m["metric_id"],
                               f"Property '{prop}' inside string literal \"{literal}\" - TransformQuery corruption risk")

    def check_metric_id_hygiene(self, m: dict):
        """Check 6: MetricId hygiene - no dots, no dashes"""
        mid = m["metric_id"]
        if not mid:
            return
        if "." in mid:
            self.error(m["line_no"], mid, "MetricId contains dot (belongs to History_Metric)")
        if "-" in mid:
            self.error(m["line_no"], mid, "MetricId contains dash")

    def check_enum_values(self, m: dict):
        """Check 7: Enum validation"""
        vt = m["value_type"]
        if vt and vt != "\\N" and vt not in VALID_VALUE_TYPES:
            self.warn(m["line_no"], m["metric_id"], f"Unknown ValueType: {vt}")

        mt = m["metric_type"]
        if mt and mt != "\\N" and mt not in VALID_METRIC_TYPES:
            self.warn(m["line_no"], m["metric_id"], f"Unknown MetricType: {mt}")

        dt = m["data_type"]
        if dt and dt != "\\N" and dt not in VALID_DATA_TYPES:
            self.warn(m["line_no"], m["metric_id"], f"Unknown DataType: {dt}")

    def check_description_prefix(self, m: dict):
        """Check 8: Description prefix present"""
        desc = m["description"]
        if not desc or desc == "\\N":
            return

        prefixes = ["QM - ", "Agent Group - ", "Agent - "]
        if not any(desc.startswith(p) for p in prefixes):
            self.warn(m["line_no"], m["metric_id"],
                      f"Description missing standard prefix (QM/Agent Group/Agent)")

    def check_catalog_completeness(self, m: dict):
        """Check 9: Catalogue field completeness for active metrics"""
        # Only check if we have catalogue columns
        if self.column_count < FULL_COLUMN_COUNT:
            return

        # Only check active metrics (not duplicate/deprecated)
        status = m.get("catalog_status", "")
        if status in ("duplicate", "deprecated"):
            return

        mid = m["metric_id"]
        display_name = m.get("display_name", "")
        short_desc = m.get("short_description", "")

        # WARNING if DisplayName or ShortDescription missing for active metrics
        if is_null(display_name):
            self.warn(m["line_no"], mid, "Catalogue: DisplayName missing (authoring backlog)")
        if is_null(short_desc):
            self.warn(m["line_no"], mid, "Catalogue: ShortDescription missing (authoring backlog)")

    def check_catalog_status(self, m: dict):
        """Check 10: CatalogStatus validation"""
        # Only check if we have catalogue columns
        if self.column_count < FULL_COLUMN_COUNT:
            return

        status = m.get("catalog_status", "")
        if is_null(status):
            return

        if status not in VALID_CATALOG_STATUSES:
            self.error(m["line_no"], m["metric_id"],
                       f"Invalid CatalogStatus: '{status}' (must be one of {VALID_CATALOG_STATUSES})")


def main():
    parser = argparse.ArgumentParser(description="RTSGrid_Metric catalogue linter")
    parser.add_argument("--sql", default="db/data/02_metrics.sql",
                        help="Path to metrics SQL file")
    parser.add_argument("--ignore-known", action="store_true",
                        help="Skip known defects pending separate fix")
    parser.add_argument("--rtm", default="RTM/RTM",
                        help="Path to RTM engine source (unused, functions hardcoded)")
    args = parser.parse_args()

    sql_path = Path(args.sql)
    rtm_path = Path(args.rtm)

    if not sql_path.exists():
        print(f"ERROR: SQL file not found: {sql_path}")
        return 1

    linter = Linter(sql_path, rtm_path, args.ignore_known)
    return linter.run()


if __name__ == "__main__":
    sys.exit(main())
