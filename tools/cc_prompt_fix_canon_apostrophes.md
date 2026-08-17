# tools/cc_prompt_fix_canon_apostrophes.md — fix apostrophe-doubling in the Curator Continuity Canon (RTM v3)
> Authored by curator-0611. Native-CC, v3 ONLY, NO push. The prior canon commit (a110044) doubled every apostrophe
> (native-CC quote-escape defect). This re-materialises the canon by BYTE-COPYING the clean staged file (no heredoc embed).

## (0) branch v3; commit.lock free; §0.5 object-store.
## (1) TASK — byte-copy, do NOT retype:
python3 - <<'PY'
import os,shutil
src=".coord/staging/curator-continuity-canon.md"
dst=".coord/protocols/curator-continuity-canon.md"
data=open(src,"rb").read()
with open(dst,"wb") as f: f.write(data); f.flush(); os.fsync(f.fileno())
assert open(dst,encoding="utf-8").read().count("''")==0, "still has doubled apostrophes"
print("clean copy written, doubled-apos=0")
PY
## (2) VERIFY: grep -c "''" .coord/protocols/curator-continuity-canon.md  == 0 ; tail -1 proper EOF ; byte/NUL clean.
## (3) COMMIT (v3, commit.lock, NO push):
git add -f .coord/protocols/curator-continuity-canon.md
git commit -m "fix(spine): Curator Continuity Canon — re-materialise clean (native-CC apostrophe-doubling defect in a110044)"
## §0.6a RESULT -> .coord/cc/curator.md ; journal ; release lock ; §0.7 re-sync ; NO push ; report hash + doubled-apos=0.
