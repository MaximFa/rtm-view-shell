#!/usr/bin/env python3
"""
gen_catalog_backfill.py - Generate idempotent SQL to backfill RTSGrid_Metric catalogue columns

Reads docs/metrics-catalog.json and emits UPDATE statements for each metric.
Mapping: JSON field → DB column

Usage:
    python tools/gen_catalog_backfill.py
    python tools/gen_catalog_backfill.py --out db/migrations/20260606_003_catalog_backfill.sql
"""

import argparse
import json
import os
import sys
from pathlib import Path


# JSON field → DB column mapping
FIELD_MAP = {
    "displayName": "DisplayName",
    "shortDescription": "ShortDescription",
    "longDescription": "LongDescription",
    "comparison": "Comparison",
    "standardKpi": "StandardKpi",
    "standardRef": "StandardRef",
    "category": "CatalogCategory",
    "family": "Family",
    "channel": "Channel",
    "thresholdSec": "ThresholdSec",
    "status": "CatalogStatus",
    "notes": "CatalogNotes",
}


def escape_sql(val: str | None) -> str:
    """Escape string for SQL (double single quotes)"""
    if val is None or val == "":
        return "NULL"
    escaped = val.replace("'", "''")
    return f"'{escaped}'"


def generate_update(metric: dict) -> str:
    """Generate UPDATE statement for one metric"""
    metric_id = metric.get("metricId", "")
    if not metric_id:
        return ""

    set_parts = []
    for json_field, db_col in FIELD_MAP.items():
        val = metric.get(json_field)

        # Handle different types
        if json_field == "thresholdSec":
            # Integer or NULL
            if val is None:
                set_parts.append(f'"{db_col}" = NULL')
            else:
                set_parts.append(f'"{db_col}" = {int(val)}')
        else:
            # String or NULL
            set_parts.append(f'"{db_col}" = {escape_sql(val)}')

    set_clause = ",\n    ".join(set_parts)
    return f'''UPDATE "RTSGrid_Metric" SET
    {set_clause}
WHERE "MetricId" = '{metric_id}';'''


def main():
    parser = argparse.ArgumentParser(description="Generate RTSGrid_Metric catalogue backfill SQL")
    parser.add_argument("--catalog", default="docs/metrics-catalog.json",
                        help="Path to metrics-catalog.json")
    parser.add_argument("--out", default=None,
                        help="Output file path (default: stdout)")
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    if not catalog_path.exists():
        print(f"ERROR: Catalog file not found: {catalog_path}", file=sys.stderr)
        return 1

    with open(catalog_path, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    metrics = catalog.get("metrics", [])
    if not metrics:
        print("ERROR: No metrics found in catalog", file=sys.stderr)
        return 1

    # Generate SQL
    lines = [
        "-- RTSGrid_Metric catalogue backfill",
        f"-- Generated from {args.catalog}",
        f"-- Metrics: {len(metrics)}",
        "",
        "BEGIN;",
        "",
    ]

    for metric in metrics:
        update = generate_update(metric)
        if update:
            lines.append(update)
            lines.append("")

    lines.append("COMMIT;")

    output = "\n".join(lines)

    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(output)
            f.flush()
            os.fsync(f.fileno())
        print(f"Written: {out_path} ({len(metrics)} metrics)")
    else:
        print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
