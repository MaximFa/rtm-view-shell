#!/usr/bin/env python3
"""Add 2 missing metrics to db/data/02_metrics.sql."""

import os

path = r"D:\Claude\Projects\RTM View Shell\db\data\02_metrics.sql"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Only add QueueNumOutboundCalls and QueueNumTransferredCalls
# (QueueNumAbandonedCalls and QueueNumAbandonedCallbacks already exist)
new_rows = "\t".join([
    "QueueNumOutboundCalls",
    "QM - Number of Outbound Calls",
    "Interactions Summary",
    "InteractionsCount",
    '(InteractionType=="Call") && (CallType=="External")  && Direction == "Outgoing"',
    "\\N",
    "\\N",
    "number",
    "Data"
]) + "\n" + "\t".join([
    "QueueNumTransferredCalls",
    "QM - Number of Transferred Calls",
    "Interactions Summary",
    "InteractionsCount",
    '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsTransferred',
    "\\N",
    "\\N",
    "number",
    "Data"
]) + "\n"

# Find the \. terminator - it's on its own line
marker = "\n\\.\n"
idx = text.find(marker)
if idx == -1:
    print("ERROR: Could not find COPY terminator")
    exit(1)

# Insert before the \.
text = text[:idx + 1] + new_rows + text[idx + 1:]

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Added 2 metrics (QueueNumOutboundCalls, QueueNumTransferredCalls)")
print("Total lines: %d" % (text.count('\n') + 1))
