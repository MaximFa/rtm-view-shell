# CC Task — ENVIRONMENT PROBE (read-only diagnostic, no commit/claim/barrier)

> Purpose: determine EXACTLY what CC's shell environment provides, to fix the python3 dependency
> in the protocol (Track 2 wrapper, §0.3 writes, S3 lock). READ-ONLY — touches nothing tracked,
> writes nothing to .coord/, makes no commit. Skip the integrity/sync/lock machinery entirely.
> Just run the block and PASTE THE FULL OUTPUT back to the operator.

```bash
cd "D:\Claude\Projects\RTM View Shell"
echo "=== shell / OS ==="
uname -a 2>/dev/null || echo "(no uname)"
echo "SHELL=$SHELL"; echo "OSTYPE=$OSTYPE"; echo "MSYSTEM=$MSYSTEM"
bash --version 2>/dev/null | head -1

echo "=== python interpreters on PATH ==="
command -v python3 >/dev/null && { echo "python3 -> $(command -v python3)"; python3 --version 2>&1; } || echo "python3: NOT FOUND"
command -v python  >/dev/null && { echo "python  -> $(command -v python)";  python  --version 2>&1; } || echo "python: NOT FOUND"
command -v py      >/dev/null && { echo "py      -> $(command -v py)";       py --version 2>&1; }      || echo "py: NOT FOUND"

echo "=== can the §0.3 write+fsync pattern actually run? ==="
PYBIN="$(command -v python3 || command -v python)"
if [ -n "$PYBIN" ]; then
  "$PYBIN" - <<'PY'
import os, sys
p = os.path.join(os.environ.get("TEMP","/tmp"), "cc_env_probe.txt")
with open(p,"w",encoding="utf-8") as f:
    f.write("ok"); f.flush(); os.fsync(f.fileno())
print("PYTHON WRITE+FSYNC OK via", sys.executable)
PY
else
  echo "*** NO python interpreter on PATH -> all protocol Python steps fail; pure-bash fallback REQUIRED ***"
fi

echo "=== other tools ==="
command -v git  >/dev/null && git --version || echo "git: NOT FOUND"
command -v psql >/dev/null && echo "psql -> $(command -v psql)" || echo "psql: NOT on PATH"
command -v pwsh >/dev/null && echo "pwsh present" || (command -v powershell >/dev/null && echo "powershell present" || echo "no pwsh/powershell on PATH")
echo "=== probe complete ==="
```

## Report
Paste the ENTIRE output above. Key questions it answers:
1. Is `python3` on PATH, or only `python` (or `py`), or neither?
2. Does the write+fsync pattern run?
3. Is this git-bash/MSYS (MSYSTEM set) or something else?
No commit. No push. No claims. Nothing to reconcile.
