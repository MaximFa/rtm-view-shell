# CC task — RTM Service: configurable NamedPipe name (parallel-run vs legacy) — §4 PRE-BLESSED

> For running OUR RTM Service in PARALLEL with the working LEGACY RTM Service on the same host: legacy hosts pipe "rtmpipe" (unpatchable). OUR service must host a DISTINCT pipe name (e.g. "rtmpipe_v3") so the multi-target adapter (RTM.Twilio) can feed BOTH without a pipe-name collision. Make our pipe name CONFIGURABLE via appsettings, default "rtmpipe" (backward-compat). Owner: backend. Native CC. Branch **v3**. Commit `fix(rtm):`. **NO push** (§37). Report-scoped.

## Mandatory reads
Read: .claude/skills/session-coord/session-coord.md; .claude/skills/role-backend/role-backend.md (if present). CLAUDE.md §0.2/§0.3/§0.5/§0.6, §33.

## INIT — §0.6a integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git fetch origin && git rev-parse origin/v3   # local >= origin/v3 (7ae4507)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
  [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
§0.3 Python+fsync; Edit BANNED. After each write: tail -3 + wc -l.

## §0.6b BINDING PREAMBLE → .coord/cc/backend.md (Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_rtm_configurable_pipename.md | status: open
### DIRECTIVE (spec->CC): RTM Service configurable NamedPipe name (AppConfig.PipeName, default "rtmpipe") for parallel-run vs legacy. v3, fix(rtm):, NO push, §4. Report build=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, rtm)
- RTM/RTM.Configuration/AppConfig.cs — ADD PipeName property + read
- RTM/RTM/RTMAdapter.cs — use AppConfig.PipeName at the NamedPipeServer ctor
- RTM/RTM/appsettings.json — add "PipeName": "rtmpipe" to RTM section

## THE WORK

### EDIT 1 — AppConfig.cs: new property (mirror AdapterServiceName style, ~L27)
OLD (anchor, ~L27):
```
        public static string AdapterServiceName { get; set; }
```
NEW (add the PipeName property right after it):
```
        public static string AdapterServiceName { get; set; }

        public static string PipeName { get; private set; }
```

### EDIT 2 — AppConfig.cs Initialize: read with default (mirror the read block, ~L59)
OLD (anchor, ~L59):
```
                AdapterServiceName = configuration["RTM:AdaptorServiceName"];
```
NEW (add the PipeName read right after):
```
                AdapterServiceName = configuration["RTM:AdaptorServiceName"];

                PipeName = string.IsNullOrWhiteSpace(configuration["RTM:PipeName"]) ? "rtmpipe" : configuration["RTM:PipeName"];
                AsyncLogger.Info($"AppConfig.PipeName = {PipeName}");
```
(Backward-compat: missing/empty RTM:PipeName → "rtmpipe" = current behavior.)

### EDIT 3 — RTMAdapter.cs L155: use the config value
OLD (L155):
```
            server = new NamedPipeServer("rtmpipe");
```
NEW:
```
            server = new NamedPipeServer(AppConfig.PipeName);
```
(Ensure the file can see AppConfig — add `using RTM.Configuration;` to RTMAdapter.cs usings IF not already present. Verify the namespace of AppConfig by reading its file header; use whatever `namespace` AppConfig declares.)

### EDIT 4 — appsettings.json: add default PipeName to RTM section (~L17-18)
OLD (anchor):
```
    "AdaptorServiceName": "RTMView.Nayax",
    "DiagPushLogging": false
```
NEW:
```
    "AdaptorServiceName": "RTMView.Nayax",
    "DiagPushLogging": false,
    "PipeName": "rtmpipe"
```
(Committed default = "rtmpipe" for backward-compat. Operator overrides to "rtmpipe_v3" on the parallel-run box; server config is preserved across deploys per §DEPLOY-16.)

## VERIFY / DoD — REPORT NUMBERS
- **Object-store:** AppConfig has `PipeName {get; private set;}` + reads `RTM:PipeName` with "rtmpipe" default; RTMAdapter.cs:155 uses `AppConfig.PipeName` (+ using RTM.Configuration if needed); appsettings RTM has `"PipeName": "rtmpipe"`. `grep -c '"rtmpipe"' RTM/RTM/RTMAdapter.cs` = 0 (no hardcoded literal left in the ctor).
- **Build — REPORT NUMBERS:** `dotnet build RTM/RTM/RTM.csproj -c Release` (or the RTM solution) = **0 errors** (report warnings). If FAILS → report verbatim, do NOT commit.
- **Backward-compat:** with no RTM:PipeName (or the default "rtmpipe") → identical to today.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the 3 files (+ role-backend.md via `git add -f` if CAPTURE). Commit `fix(rtm): configurable NamedPipe name (AppConfig.PipeName, default rtmpipe) for parallel-run vs legacy [backend]`.
- `bash tools/cc_post_commit.sh backend <hash>` (or Python+fsync journal). §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b BINDING POSTAMBLE → .coord/cc/backend.md
```
### RESULT (CC->spec): commit <hash> . build <0 err/W n> . files AppConfig.cs + RTMAdapter.cs + appsettings.json . PipeName configurable (default rtmpipe) . status done|failed . blockers . verified: object-store + build
```
