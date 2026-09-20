#!/usr/bin/env python3
"""
lint_probe.py - the gate every probe passes BEFORE it is handed to the operator.

Written 2026-09-18 by devops-0916 after the same class of fault caught the role three times in two days:
  [E1] inside -like   (a character class, not a literal)      2026-09-17
  a helper named H    (alias Get-History wins over functions)  2026-09-18
  $l next to $L       (variable names are case-insensitive)    2026-09-18
Each time a paragraph went into the role skill. Paragraphs did not stop the next one - they require
future-me to recall the right paragraph at the right second. This file does not require recall.

Usage:  python3 tools/lint_probe.py .probes/<file>.ps1 [more.ps1 ...]
Exit 0 = may be handed out. Exit 1 = do not hand out.

GRAMMAR LIMIT - READ THIS BEFORE TRUSTING A GREEN FROM THIS GATE
    The operator runs the probes under Windows PowerShell 5.1. The parser stage of this gate runs
    under PowerShell 7. The two grammars are close but NOT identical, so:
      * a green here is NOT proof that 5.1 will accept the file;
      * a parse error here is not proof that 5.1 rejects it either.
    The linter's own checks below are grammar-independent and hold for both.
    Named in the gate itself, not only in a letter: a letter is read once, a header every time.
    (coordinator-0917, 19.09: "a gate we are about to post as a sentinel over the operator's boxes
    checks a grammar the boxes are not executed under.")

SUPERSET WARNING
    The case-collision check below is a REGEX approximation. In PowerShell an assignment inside a
    function creates a NEW LOCAL, so $lines there does not clobber a script-level $Lines. Measured
    19.09 over the whole registry: of 19 files flagged, 14 were real and 3 were benign. Until this
    check is moved to the AST, treat its output as "look here", not as "this is broken".
"""
import re, sys, os

# one-letter and short names PowerShell already owns (aliases beat functions in resolution order)
PS_ALIASES = set("""h r s ls cd cp mv rm ft fl fw gm gc gi gp sp gu ni ri ply sls cat dir echo kill man md
mount popd ps pushd pwd sleep sort tee type where write cls clear copy del diff move rd ren set gal gbp
gcm gdr ghy gjb gl gmo gsv gv gwmi iex ihy ii ipmo irm iwr measure ogv oh rbp rcjb rcsn rd rdr rmo rni
rnp rp rsn rv rvpa sajb sal saps sasv sbp sc select si sl sp start sv swmi tee wget curl""".split())

def check(path):
    raw = open(path, 'rb').read()
    txt = raw.decode('utf-8-sig', errors='replace')
    faults, notes = [], []

    # Name checks run on CODE ONLY. A linter that fires on its own explanatory comment teaches the
    # author to ignore it, which is worse than having no linter. (Found immediately: this file's own
    # header describes the $l/$L fault in prose, and v1 of the linter failed the probe for it.)
    code = re.sub(r'(?s)<#.*?#>', '', txt)
    code = re.sub(r'(?m)^\s*#.*$', '', code)
    code = re.sub(r'(?m)\s#[^\n\'"]*$', '', code)

    # --- bytes ---------------------------------------------------------------
    ctrl = sorted({b for b in raw if b < 0x20 and b not in (9, 10, 13)})
    if ctrl:
        faults.append("control bytes present: %s  (an escape collapsed into a real byte, e.g. \\a -> 0x07)"
                      % ", ".join(hex(c) for c in ctrl))
    if raw[:3] != b'\xef\xbb\xbf':
        faults.append("no UTF-8 BOM (project rule for .ps1)")
    bare_lf = raw.count(b'\n') - raw.count(b'\r\n')
    if bare_lf:
        faults.append("%d bare LF - the file must be CRLF throughout" % bare_lf)
    if b'\x00' in raw:
        faults.append("NUL byte present")

    # --- names ---------------------------------------------------------------
    for m in re.finditer(r'(?im)^\s*function\s+([A-Za-z_][\w-]*)', code):
        fn = m.group(1)
        if len(fn) <= 2:
            faults.append("function '%s' is %d characters - too short; an alias or cmdlet can win name "
                          "resolution (Alias > Function > Cmdlet)" % (fn, len(fn)))
        if fn.lower() in PS_ALIASES:
            faults.append("function '%s' collides with a built-in alias - it will NEVER be called" % fn)

    assigned = {m.group(1) for m in re.finditer(r'\$([A-Za-z_]\w*)\s*=', code)}
    loopvars = {m.group(1) for m in re.finditer(r'foreach\s*\(\s*\$([A-Za-z_]\w*)\s+in', code, re.I)}
    short = sorted(v for v in (assigned | loopvars) if len(v) <= 2)
    if short:
        faults.append("one/two-letter variables: %s - variable names are CASE-INSENSITIVE, so $l and $L "
                      "are one variable; give every variable a word" % ", ".join("$" + v for v in short))
    lowered = {}
    for v in (assigned | loopvars):
        lowered.setdefault(v.lower(), set()).add(v)
    for low, forms in lowered.items():
        if len(forms) > 1:
            faults.append("the same variable written in different cases: %s - PowerShell treats these as ONE"
                          % ", ".join("$" + f for f in sorted(forms)))

    # --- matching -------------------------------------------------------------
    for m in re.finditer(r'-(?:c?like|notlike)\s+[\'"]([^\'"]*)[\'"]', code, re.I):
        if '[' in m.group(1) or ']' in m.group(1):
            faults.append("-like pattern contains [ or ]: '%s' - those are a CHARACTER CLASS in wildcard "
                          "matching, not literals. Use .Contains() with StringComparison::Ordinal" % m.group(1))

    # --- formatting ------------------------------------------------------------
    for line_no, line in enumerate(txt.splitlines(), 1):
        # `-f` is the format OPERATOR only when a string/paren ends right before it. As a parameter of
        # an external program (pg_dump -f <file>, git commit -F <file>) it is not, and flagging those
        # makes the gate noisy - a noisy gate gets switched off within a week. 2026-09-20, measured on
        # probe_234_20260920_cmp01-live-filter.ps1, which was refused for `pg_dump ... -f $dumpFile`.
        # Telling the format OPERATOR from a program's -f PARAMETER by what precedes it does not work:
        # the operator accepts any expression on its left. What the operator always has is a PLACEHOLDER
        # in the format string. pg_dump -f <file> has none, ('a {0}' + $x -f $y) has one.
        is_format_operator = re.search(r'\{\d+\}', line) is not None
        if is_format_operator and re.search(r'[\'"]\s*\+\s*\$', line) and not line.strip().startswith('#'):
            notes.append("line %d: string concatenation next to -f ; the operator binds ONLY to the last "
                         "fragment, so earlier {0} stay unsubstituted" % line_no)

    # --- clocks ------------------------------------------------------------------
    # Get-Date -Format u prints LOCAL time and appends 'Z' without converting. Mixing it with a value
    # that WAS converted (.ToUniversalTime(), [datetime]::Parse('...Z')) produces an offset-sized lie.
    # Cost when this was missed: step 3 of the 0ae2102 flight declared three services "not restarted"
    # because a local 23:03 was compared against a true-UTC 23:04. 2026-09-18.
    uses_format_u = re.search(r'Get-Date\s+-Format\s+u\b', code)
    uses_real_utc = re.search(r'ToUniversalTime\(\)|\[datetime\]::UtcNow|UtcNow', code)
    if uses_format_u and uses_real_utc:
        faults.append("both `Get-Date -Format u` (LOCAL time wearing a Z) and a real UTC value "
                      "(ToUniversalTime/UtcNow) appear: any comparison between them is off by the "
                      "machine's offset. Pick one clock - (Get-Date).ToUniversalTime() everywhere - "
                      "or compare something clock-free, such as a process id")
    elif uses_format_u:
        notes.append("`Get-Date -Format u` labels LOCAL time with 'Z'. Fine for a heading, never as a "
                     "value another measurement is compared against")

    # --- external invocation ----------------------------------------------------
    if re.search(r'-File\s+\$?\w[^\n]*\s-\w+\s+[\'"]{2}(\s|$)', code):
        faults.append("an EMPTY string is passed through 'powershell.exe -File' - it is dropped and the "
                      "callee reports a missing argument. Omit the parameter (if its default is empty) "
                      "or invoke the script in-process with splatting")

    # --- stale artefacts ----------------------------------------------------------
    # Picking "the newest file in the output directory" proves nothing: the newest file can predate
    # the run by weeks. Cost when this was missed: step 4 of the 0ae2102 flight read a delta file from
    # 29 August and reported its numbers as today's, while the comparator had in fact died. 2026-09-18.
    picks_newest = re.search(r'Sort-Object\s+LastWriteTime\s+-Descending', code)
    proves_fresh = re.search(r'LastWriteTime\w*\s*-(?:gt|ge)\s|\bRunStartedAt\b|-newer', code)
    if picks_newest and not proves_fresh:
        faults.append("the probe takes the newest file in a directory but never proves that file is NEWER "
                      "THAN THIS RUN. A leftover from a previous day will be read as today's result. "
                      "Record the start time and refuse any artefact older than it")

    # --- the report must survive a broken-off run -------------------------------
    # Count the CALLS that flush the report, not the single line that implements the flush: a probe
    # with `function Write-Report { ...WriteAllLines... }` called five times is correct, and an early
    # version of this check called that "one place" - a false alarm, which is how linters get ignored.
    writes = len(re.findall(r'WriteAllLines|Out-File|Set-Content|Add-Content', code))
    writes += len(re.findall(r'(?m)^\s*(?:Write-Report|Flush)\s*\(?\)?\s*$', code))
    if writes and writes < 2 and re.search(r'&\s*(powershell\.exe|\$\w*(updater|builder|installer))', code, re.I):
        notes.append("the report is written in ONE place while the probe runs an external program: if that "
                     "run breaks the operator is left with an empty file. Flush before and after")


    # --- inherited expectations -------------------------------------------------
    # A probe is usually born by copying its predecessor. The BODY survives the copy correctly; the
    # EXPECTATIONS do not - they are parameters of one flight. Measured cost, 2026-09-20: a probe named
    # ...install-0f969d8 printed "expected ProductVersion carries 0ae2102", a value two flights old,
    # and a probe reused last flight's satellite sizes, which would have made its check unable to fail.
    # a 7-char token made only of digits is a date (20260920), not a commit - exclude it in BOTH
    # directions, or every probe named with a date reports a false fault
    def _commitish(tok): return bool(re.search(r'[a-f]', tok))
    stem_commits = set(t for t in re.findall(r'[0-9a-f]{7}', os.path.basename(path)) if _commitish(t))
    # LIMIT, stated rather than hidden: this check only works for probes whose NAME carries the
    # commit they are for. A probe named only by date gets no check here - its expectations are
    # unverifiable from the filename, and a green from this gate says nothing about them.
    if stem_commits:
        for m in re.finditer(r'(?i)expect\w*[^\n]{0,80}?\b([0-9a-f]{7})\b', code):
            if _commitish(m.group(1)) and m.group(1) not in stem_commits:
                faults.append("an EXPECTATION names commit %s while this probe is named for %s: an "
                              "expectation inherited from the probe this one was copied from. "
                              "Expectations are per-flight parameters - re-measure them, never carry "
                              "them over" % (m.group(1), '/'.join(sorted(stem_commits))))
                break

    # --- a genuine zero printed as NOT MEASURED ---------------------------------
    # SafeCount-style helpers return a sentinel (-999) when the call failed. Passing a bare
    # Get-ChildItem to them makes an EMPTY result indistinguishable from a failed one, and the report
    # says NOT MEASURED where the truth is zero. Found 2026-09-19, still shipping on 2026-09-20.
    if re.search(r'-999', code):
        bare = re.findall(r'SafeCount\s*\(\s*Get-(?:ChildItem|Process|Service)', code)
        if bare:
            faults.append("a -999 'not measured' sentinel is combined with SafeCount(Get-...) on a bare "
                          "cmdlet: an empty result reaches the sentinel and a genuine ZERO is printed as "
                          "NOT MEASURED. Wrap the call in @(...) first, and reserve -999 for a call that "
                          "actually threw")


    # --- C-style escaping inside a PowerShell string -----------------------------
    # PowerShell escapes a double quote with a BACKTICK, never with a backslash. A \" inside a
    # double-quoted string ends the string and the rest of the line becomes garbage the parser
    # refuses. Cost, 2026-09-20: probe_234_20260920_cmp01-live-filter.ps1 died at ParserError on the
    # operator's machine, one line before the measurement it existed for. The gate below is cheap;
    # the round trip through the operator is not.
    for line_no, line in enumerate(txt.splitlines(), 1):
        if line.strip().startswith('#'):
            continue
        if re.search(r'\\"', line):
            faults.append("line %d: a double quote escaped with a BACKSLASH inside a PowerShell "
                          "string - the escape character is a backtick. As written, the string ends "
                          "early and the line is a parse error" % line_no)
            break

    return faults, notes


def main(argv):
    if len(argv) < 2:
        print(__doc__); return 2
    bad = 0
    for path in argv[1:]:
        faults, notes = check(path)
        print("=" * 78)
        print(path)
        for f in faults: print("  FAULT : " + f)
        for n in notes: print("  NOTE  : " + n)
        if not faults and not notes: print("  clean")
        if faults: bad = 1
    print("=" * 78)
    print("VERDICT: " + ("DO NOT HAND OUT - faults above" if bad else "may be handed out"))
    return bad

if __name__ == '__main__':
    sys.exit(main(sys.argv))
