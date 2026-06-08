# CC Task — formalize append-ACKS + bus-reliability lessons in session-coord skill

> Coordinator-drafted (coordinator-0606). Operator-approved. You (test4-0606) ALREADY hold
> .claude/skills/session-coord/session-coord.md — no §9 needed. Single-file edit + docs: commit.
> Goal: replace the phantom-prone per-session ack files with ONE append-only ACKS file, and record
> the bus-reliability lessons (L-SC-18, L-SC-19) confirmed by the 22:00 barrier + the bus-health probe.

## Step 0 — INTEGRITY (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q; git rev-parse HEAD; git rev-parse origin/v2   # expect HEAD==origin/v2==4a4bd3b
git status --short
```

## Sync (§42) — slug test4-0606. Claim: .claude/skills/session-coord/session-coord.md (you already hold it).
S1 barrier check (content-based). S2: `python3 tools/coord_check_claims.py test4-0606 .claude/skills/session-coord/session-coord.md`.
S3 phantom-aware lock. §40 skills read. Writes Python+fsync (§0.3).

## Edit — .claude/skills/session-coord/session-coord.md (Python read-modify-write)

### (1) Lessons table — append after L-SC-17 row:
```
| L-SC-18 | The cross-view mount drop (L-SC-04) is INHERENT to the share and unsolvable from inside CC's WSL2 process: a write succeeds + verifies in the WRITER's view but is async-dropped from other views. cc_post_commit.sh verify-retry catches SAME-view write failures (good) but NOT the async cross-view drop. => coordinator journal<->git reconciliation stays PERMANENT. Durable full-close (future) = stop relying on the mount for the journal (journal as git-tracked artefact / commit trailer). |
| L-SC-19 | Per-session ack FILES in `.coord/push/acks/<slug>.md` keep failing under barrier load (L-SC-10 phantom blocks creates in the acks/ subdir AND some flat names; L-SC-04 async-drops them). FIX: collect acks in ONE append-only file `.coord/push/ACKS.md` that the coordinator PRE-CREATES at freeze (append to an existing file is far more reliable than creating new files in a phantom dir). Sessions APPEND their READY block; the push gate parses that one file by slug. Backstop when even the append drops: the session reports READY to the OPERATOR in chat -> operator relays -> coordinator records it in ACKS.md (git + operator are the reliable channels; the file-bus is best-effort). Bus-health probe (2026-06-06): single-process round-trip is fine; losses are cross-view + contention only. |
```

### (2) §5 Push barrier runbook — in step 1 (freeze), after writing request.md, ADD:
"1b. Coordinator ALSO creates `.coord/push/ACKS.md` (pre-created single file with a header) at freeze.
Sessions append their READY block here — do NOT create per-session files in `.coord/push/acks/` (L-SC-19)."
And in step 2, change "writes its OWN ack" -> "APPENDS its READY block to `.coord/push/ACKS.md`".
In step 3 (quorum), change "READY from EVERY active session" -> "a READY block per expected slug in ACKS.md
(no HOLD); operator-relayed READY recorded by coordinator counts (L-SC-19)".

### (3) §6 Ack checklist — change the Format line to:
"Format: APPEND to `.coord/push/ACKS.md` a block:
```
## <slug> | READY | <UTC>
valid_for: origin/<branch>..HEAD = <exact frozen hashes>
notes: <§6 checklist summary>
---
```
If the append does not show up for the coordinator, report READY to the operator in chat (relay backstop).
HOLD: append `## <slug> | HOLD: <reason> | <UTC>`."

### (4) §7.2 — replace the `### 7.2 Ack — .coord/push/acks/<slug>.md` template with:
"### 7.2 Ack — append a block to the single `.coord/push/ACKS.md` (L-SC-19)
(per-session `acks/<slug>.md` files are DEPRECATED — phantom-prone). Coordinator pre-creates ACKS.md at
freeze; each session appends one `## <slug> | READY | <UTC>` block (format in §6). Gate parses by slug."

### (5) Header version line (line ~5): bump to:
"updated: 2026-06-07 (v1.7 — L-SC-18 cross-view inherent + L-SC-19 append-ACKS; Track 2 wrapper)"

## Verify
```bash
grep -c "L-SC-19\|L-SC-18" .claude/skills/session-coord/session-coord.md   # >=2
grep -c "ACKS.md" .claude/skills/session-coord/session-coord.md            # >=3
tail -3 .claude/skills/session-coord/session-coord.md
```

## Commit (docs module; .claude/ is gitignored -> git add -f; §39.3)
```bash
bash tools/pre-commit-check.sh
git add -f .claude/skills/session-coord/session-coord.md
git commit -m "docs: session-coord v1.7 — append-ACKS (L-SC-19) + cross-view-inherent (L-SC-18)"
# then the wrapper (your Track 2):
bash tools/cc_post_commit.sh test4-0606 $(git log -1 --format=%h)
```
§0.6 verify + PD-007 re-sync the skill file from HEAD. NO push (§37) — rides the next barrier.
Coordinator will adopt ACKS.md creation at the next freeze + update the push-barrier gate to parse it.

## Peer review: this is coordinator-drafted; operator issues directly.
