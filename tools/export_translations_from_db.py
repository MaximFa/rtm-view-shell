#!/usr/bin/env python3
"""
export_translations_from_db.py — Export metric translations from DB to docs/metrics-catalog.<locale>.json

WORKFLOW:
1. Edit translations in the admin UI (DB: RTSGrid_MetricTranslation)
2. Run this tool: python tools/export_translations_from_db.py --password <pw>
3. Regenerate seed SQL: python tools/gen_translation_backfill.py --out db/data/05_metric_translations.sql
4. Commit both JSON files + db/data/05_metric_translations.sql

This tool reads RTSGrid_MetricTranslation for each supported locale and updates
docs/metrics-catalog.<locale>.json with the current DB values. Idempotent.
"""

import argparse
import json
import os
import sys

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


SUPPORTED_LOCALES = ["ru-RU", "he-IL"]
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def get_connection(args):
    """Create DB connection from args."""
    return psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password
    )


def export_translations(conn, locale):
    """Read translations for a locale from DB."""
    cur = conn.cursor()
    cur.execute('''
        SELECT "MetricId", "DisplayName", "ShortDescription", "LongDescription", "Comparison"
        FROM "RTSGrid_MetricTranslation"
        WHERE "Locale" = %s
        ORDER BY "MetricId"
    ''', (locale,))
    rows = cur.fetchall()
    cur.close()
    return {row[0]: {
        "metricId": row[0],
        "displayName": row[1],
        "shortDescription": row[2],
        "longDescription": row[3],
        "comparison": row[4]
    } for row in rows}


def update_json_file(locale, db_translations):
    """Update docs/metrics-catalog.<locale>.json with DB translations."""
    json_path = os.path.join(PROJECT_ROOT, "docs", f"metrics-catalog.{locale}.json")

    if not os.path.exists(json_path):
        print(f"  WARNING: {json_path} does not exist, skipping")
        return 0

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    updated = 0
    metrics = data.get("metrics", [])

    for m in metrics:
        metric_id = m.get("metricId")
        if metric_id and metric_id in db_translations:
            db_t = db_translations[metric_id]
            # Update fields from DB (only if DB has a value)
            if db_t.get("displayName"):
                m["displayName"] = db_t["displayName"]
            if db_t.get("shortDescription"):
                m["shortDescription"] = db_t["shortDescription"]
            if db_t.get("longDescription"):
                m["longDescription"] = db_t["longDescription"]
            if db_t.get("comparison"):
                m["comparison"] = db_t["comparison"]
            updated += 1

    # Write back with stable key order
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())

    return updated


def main():
    parser = argparse.ArgumentParser(description="Export metric translations from DB to JSON")
    parser.add_argument("--host", default="localhost", help="PostgreSQL host")
    parser.add_argument("--port", type=int, default=5432, help="PostgreSQL port")
    parser.add_argument("--dbname", default="rtmviewdb", help="Database name")
    parser.add_argument("--user", default="ccdashboard_user", help="Database user")
    parser.add_argument("--password", required=True, help="Database password")
    args = parser.parse_args()

    print(f"Connecting to {args.user}@{args.host}:{args.port}/{args.dbname}")
    conn = get_connection(args)

    total_exported = 0
    for locale in SUPPORTED_LOCALES:
        print(f"\nExporting {locale}...")
        db_translations = export_translations(conn, locale)
        print(f"  Found {len(db_translations)} translations in DB")

        updated = update_json_file(locale, db_translations)
        print(f"  Updated {updated} metrics in docs/metrics-catalog.{locale}.json")
        total_exported += len(db_translations)

    conn.close()
    print(f"\nTotal: {total_exported} translations exported")
    print("Next: run `python tools/gen_translation_backfill.py --out db/data/05_metric_translations.sql`")


if __name__ == "__main__":
    main()
