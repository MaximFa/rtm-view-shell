# .probes — measurement scripts I hand to the operator

The reverse direction of `.measurements/`: **out** to a server, where that folder is **in**.

## Why this exists

Pasting a 100-line run-box into the chat costs context twice — once when I write it, once when the
console echoes it back. The operator asked (2026-09-05) for the box to travel as a FILE instead:
I write it here, he copies it to the server, runs one short line, and brings back the output.

## The flow, fixed

1. I write `probe_<SERVER>_<YYYYMMDD_HHMMSS>_<topic>.ps1` into this folder.
2. Operator copies it to `C:\RTMView-Ops\incoming\` on that server.
   That ops root exists on every deployed server by project convention (CLAUDE.md §43:
   `incoming\` = scripts staged to apply, `output\` = reports and logs). Nothing new is invented.
3. Operator runs ONE line (the probe prints it back too):

       Get-ChildItem C:\RTMView-Ops\incoming\*.ps1 | Unblock-File
       powershell -ExecutionPolicy Bypass -File C:\RTMView-Ops\incoming\<probe>.ps1

   `Unblock-File` is not optional: a .ps1 that travelled from another machine carries the
   mark-of-the-web and PowerShell refuses it as unsigned (standing deploy trap, role-devops §B).
4. The probe writes its output into `C:\RTMView-Ops\output\` and prints the exact paths.
5. Operator copies those into `.measurements/` here, under the naming convention in its README.

## Rules for every probe file

- **UTF-8 WITH BOM + CRLF.** Windows PowerShell 5.1 decodes a BOM-less file by the ANSI codepage;
  any non-ASCII byte then breaks a string literal and the script dies with a ParserError
  (CLAUDE.md §35; role-devops §B 2026-07-13). Verify first bytes are `EF BB BF`.
- **Read-only unless the task says otherwise**, and it says so in its own header.
- **Self-describing:** first line printed is WHERE IT RUNS — machine, database, read-or-write.
- **The gate is inside the probe**, not in the operator's head: exit code, stderr size as a
  CONDITION, end-of-run marker, negative controls printed explicitly. Last line says PASS or FAIL.
- **Never a password prompt in the clear**, and never a password echoed: read it from the
  machine's own config, print only its length.
- A re-run gets a NEW file name with a new timestamp — never an overwrite of an existing probe.

## A probe that CREATES something leaves its mark next to it (added 2026-09-12, devops-0912)

Measured cost, not theory: on 2026-09-12 two of my probes were each executed twice. Both first runs
completed and created their directories; both second runs hit `must NOT exist yet` and refused. The gate
was right to refuse - an existing artifact is never silently reused - but it could only say "this exists",
never "this is MY OWN previous result". Two extra operator turns were spent establishing by file
timestamps what the probe could have stated itself.

Rules from that, for every probe that creates a directory, a package or any other artifact:

- **Stamp the name.** A created directory carries the run stamp (`..._<yyyyMMdd_HHmmss>`), so two runs of
  one probe never collide in the first place.
- **Write an `.origin` file inside what you create**, one line: probe file name, probe sha256, run stamp,
  machine, and the revision the artifact was made from. The data is already printed in the report - the
  point is that it lives NEXT TO the artifact, which is what the next run can read.
- **On "it already exists", read the mark and distinguish three cases**: my own previous run (say so,
  print its stamp, and let the operator choose re-use or a fresh stamped name) / another probe's artifact
  (do not touch) / no mark at all, so the origin is unknown (do not touch, and say which of the three it
  is). "Exists" alone is not an answer.
- **The first section of the report says what the probe FOUND on entry**, before its first write - existing
  directories and their marks - not only what it did.
- Never delete or overwrite an artifact you did not create in this run, with or without a mark.
