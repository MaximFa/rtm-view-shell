#!/usr/bin/env python3
"""
lint_metrics.py - RTSGrid_Metric catalogue validator

Validates db/data/02_metrics.sql against the RTM engine function inventory.
Detects: misspelled MetricFunction, broken Calc references, duplicates, hygiene issues.

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


def parse_sql_copy(sql_path: Path) -> list[dict]:
    """Parse the COPY block from 02_metrics.sql"""
    metrics = []
    in_copy = False
    
    with open(sql_path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.rstrip("\r\n")
            
            if line.startswith("COPY \"RTSGrid_Metric\""):
                in_copy = True
                continue
            
            if in_copy:
                if line == "\\.":
                    break
                
                # Tab-separated: MetricId, Description, DataType, MetricFunction,
                # MetricParameter, MetricFormat, DefaultValue, ValueType, MetricType
                parts = line.split("\t")
                metrics.append({
                    "line_no": line_no,
                    "raw": line,
                    "parts": parts,
                    "metric_id": parts[0] if len(parts) > 0 else "",
                    "description": parts[1] if len(parts) > 1 else "",
                    "data_type": parts[2] if len(parts) > 2 else "",
                    "metric_function": parts[3] if len(parts) > 3 else "",
                    "metric_parameter": parts[4] if len(parts) > 4 else "",
                    "metric_format": parts[5] if len(parts) > 5 else "",
                    "default_value": parts[6] if len(parts) > 6 else "",
                    "value_type": parts[7] if len(parts) > 7 else "",
                    "metric_type": parts[8] if len(parts) > 8 else "",
                })
    
    return metrics


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


def get_bag(data_type: str, metric_function: str) -> str:
    """Determine bag for duplicate detection"""
    if metric_function in STATUS_COUNTER_FUNCS:
        return "IGNORED"
    if data_type == "UsersInteraction":
        return "UsersInteraction"
    return "OTHER"


class Linter:
    def __init__(self, sql_path: Path, rtm_path: Path, ignore_known: bool = False):
        self.sql_path = sql_path
        self.rtm_path = rtm_path
        self.ignore_known = ignore_known
        self.errors = []
        self.warnings = []
        self.metrics = []
        self.metric_ids = set()
        
    def error(self, line_no: int, metric_id: str, msg: str):
        self.errors.append(f"ERROR L{line_no} [{metric_id}]: {msg}")
        
    def warn(self, line_no: int, metric_id: str, msg: str):
        self.warnings.append(f"WARN  L{line_no} [{metric_id}]: {msg}")
    
    def run(self) -> int:
        self.metrics = parse_sql_copy(self.sql_path)
        
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
            
            # Duplicate detection
            if m["metric_id"] and m["default_value"] != "\\N":
                key = (
                    m["metric_function"],
                    canonical_param(m["metric_parameter"]),
                    get_bag(m["data_type"], m["metric_function"]),
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
        """Check 1: Column count must be exactly 9"""
        if len(m["parts"]) != 9:
            self.error(m["line_no"], m["metric_id"], 
                       f"Column count {len(m['parts'])} != 9")
    
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