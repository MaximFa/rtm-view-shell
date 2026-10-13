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

    # --- a helper called but never defined -------------------------------------
    # Measured on myself twice. 2026-10-10: the acceptance of 4634162 called Line() where the probe
    # defines Rule(), the trap swallowed it and a whole section was skipped under a GREEN verdict.
    # 2026-10-12: the install probe of f333db5 called Find-ByteRun three times without defining it;
    # the call returned nothing, the row printed "needle present : False" with an empty offset, and
    # with the predicate the other way round that would have been a FALSE GREEN on production.
    # These are MY helpers, not cmdlets: if one is called in a file, that file must define it.
    sources_core = bool(re.search(r"_core\.ps1", code))
    OWN_HELPERS = ('Find-ByteRun', 'Get-Sha256Of', 'Invoke-Native', 'Protect-Line', 'Stamp-Of',
                   'Invoke-Select', 'Test-Offset', 'Write-Report', 'ShaOf', 'StateOf', 'CountOf',
                   'Say', 'Rule', 'Finish', 'Line')
    defined = set(re.findall(r'(?m)^\s*function\s+([A-Za-z][A-Za-z0-9_-]*)', code))
    for helper in OWN_HELPERS:
        if helper in defined:
            continue
        # a call looks like "Helper arg" or "(Helper arg)" or "$x = Helper ..." - never "function Helper"
        # A NAME IS NOT A CALL when it is a property or a key: 'Line = $line' inside @{ } matched
        # the first version of this gate and produced a false red on a correct probe (measured
        # 2026-10-12). A call is the name followed by whitespace or '(' and NOT by '='.
        called = None
        # A DOT before the name means a property access: '$record.Line' produced the second
        # false red of this gate's first hour. Short helper names (Say, Rule, Line) are the
        # dangerous ones in a text gate, so the lookbehind excludes '.', '-' and word chars.
        for candidate in re.finditer(r'(?<![-\w.])' + re.escape(helper) + r'(?![\w-])', code):
            tail = code[candidate.end():candidate.end() + 12]
            if re.match(r'\s*=(?!=)', tail):
                continue
            if not re.match(r'[ (\r\n]', tail):
                continue
            line_start = code[:candidate.start()].rsplit('\n', 1)[-1]
            if 'function' in line_start:
                continue
            called = candidate
            break
        if not called:
            continue
        if sources_core:
            continue
        faults.append("the helper %s is called but this file neither defines it nor dot-sources "
                      "_core.ps1. PowerShell returns nothing for an unknown command, so the row "
                      "prints a value that was never measured - a false green when the predicate "
                      "runs the other way" % helper)
        break

    # --- a statement used where PowerShell wants an expression ------------------
    # Measured on myself 2026-10-13, inside the fix for the false red of the run before: I wrote
    # ([regex]::Matches((if ($rows.Count -gt 0) { $text } else { '' }), $pattern)). In PowerShell
    # 5.1 `if` is a STATEMENT - it is an expression only inside $( ). Bare `(if ...)`, `(foreach`,
    # `(while`, `(switch`, `(try` is a parse error, which means the probe dies at line 1 and the
    # operator gets a red console instead of a measurement. Caught here, before the box.
    for keyword_match in re.finditer(r'\((if|foreach|while|switch|try|do)[\s(]', code):
        if code[keyword_match.start() - 1:keyword_match.start()] == '$':
            continue
        faults.append("line %d: `(%s ...` - %s is a STATEMENT in PowerShell, an expression only "
                      "inside $( ). Bare parentheses here are a parse error and the probe never "
                      "reaches its first measurement. Write $(%s ...)"
                      % (code[:keyword_match.start()].count('\n') + 1, keyword_match.group(1),
                         keyword_match.group(1), keyword_match.group(1)))
        break

    # --- defined, but BELOW the first call ---------------------------------------
    # Measured on myself 2026-10-12, one hour after fixing the gate above: Find-ByteRun was defined
    # at the bottom of section 6 and called in the same section, so the call ran first, the trap
    # fired, the row printed False and the acceptance of a GOOD flight said NOT ACCEPTED. Presence
    # of a definition is not enough; it must come first.
    if not sources_core:
        for helper in OWN_HELPERS:
            definition = re.search(r'(?m)^\s*function\s+' + re.escape(helper) + r'\b', code)
            if not definition:
                continue
            call = None
            for candidate in re.finditer(r'(?<![-\w.])' + re.escape(helper) + r'(?![\w-])', code):
                tail = code[candidate.end():candidate.end() + 12]
                if re.match(r'\s*=(?!=)', tail):
                    continue
                if not re.match(r'[ (\r\n]', tail):
                    continue
                line_start = code[:candidate.start()].rsplit('\n', 1)[-1]
                if 'function' in line_start:
                    continue
                call = candidate
                break
            if call and call.start() < definition.start():
                faults.append("the helper %s is CALLED on line %d but only DEFINED on line %d. "
                              "PowerShell runs a script top to bottom, so the call fails, the trap "
                              "swallows it and the row prints a value that was never measured"
                              % (helper, code[:call.start()].count('\n') + 1,
                                 code[:definition.start()].count('\n') + 1))
                break

    # --- unbalanced parentheses on one line -------------------------------------
    # Measured on myself 2026-10-12: a Say ( ... line in the daytrendfail probe was missing its
    # closing paren. The linter said "may be handed out", the parser gate in the operator's box
    # caught it, and a round of his attention was spent on a defect I could see on my own disk.
    # The linter cannot parse PowerShell, but it can count brackets outside quotes, which is
    # exactly the class of fault that reaches the operator as a wall of red.
    def _depth_delta(text):
        depth = 0
        quote = None
        index = 0
        while index < len(text):
            char = text[index]
            if quote:
                if char == quote:
                    quote = None
            elif char in ("'", '"'):
                quote = char
            elif char == '#' and depth == 0:
                break
            elif char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
            index += 1
        return depth

    for number, raw_line in enumerate(code.split('\n'), 1):
        stripped = raw_line.strip()
        if not stripped.startswith(('Say ', 'Say(', 'Write-Host')):
            continue
        if stripped.endswith(('`', '|', '+')):
            continue
        delta = _depth_delta(stripped)
        if delta != 0:
            faults.append("line %d: %d unclosed parenthesis/es on a single Say/Write-Host line - "
                          "PowerShell will refuse the whole file at parse time, and the operator "
                          "finds out instead of me: %s" % (number, abs(delta), stripped[:70]))
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
    # double-quoted string ENDS THE STRING there.
    # The consequence is NOT always a parse error, and saying so was a defect of this gate's own
    # message. Measured 2026-09-20 with pwsh 7.4.6 ParseFile on both shapes:
    #   probe_234_20260920_cmp01-live-filter.ps1  -> ParserError on the operator's machine, one line
    #       before the measurement it existed for. The loud case.
    #   Say "  ...[string]$MigrationList = \"\" as its"  -> errors 0. It PARSES, runs, and prints
    #       "  ...[string] = \" - the variable name swallowed, the rest of the sentence gone. The
    #       quiet case, and it rode through a live install on 234 unnoticed because the run was green.
    # A message that promises a crash teaches the reader to dismiss this fault when nothing crashed -
    # which is exactly how the quiet case survived. So the message names BOTH outcomes.
    for line_no, line in enumerate(txt.splitlines(), 1):
        if line.strip().startswith('#'):
            continue
        if re.search(r'\\"', line):
            faults.append("line %d: a double quote escaped with a BACKSLASH inside a PowerShell "
                          "string - the escape character is a backtick. The string ENDS at that "
                          "quote. Sometimes that is a parse error; sometimes it parses cleanly and "
                          "the line silently PRINTS THE WRONG TEXT, which is worse because the run "
                          "stays green. Do not dismiss this because nothing crashed - read what the "
                          "line actually prints" % line_no)
            break

    # --- a document that lies about ITSELF ---------------------------------------
    # Twice in two days a probe carried its predecessor's identity in PRINTED text while doing the
    # new flight's work: "END-OF-RUN MARKER: INSTALL-0F969D8-COMPLETE" inside install-251ca40, and
    # "ACCEPTANCE OF 934a1c5" in a report about another commit. Nothing breaks - which is why it
    # keeps happening: it is caught by eye, and the eye, when a probe is copied, reads the
    # PARAMETERS and skips the print statements.
    # The rule: if the FILENAME carries a commit, no printed marker, banner or report title may
    # carry a different one. Provenance lines are exempt and say so in words ("BASED ON", "copied
    # from", "previous"): naming the ancestor is the honest case this gate must not punish.
    if stem_commits:
        for line_no, line in enumerate(txt.splitlines(), 1):
            if not re.search(r'(?i)(END-OF-RUN MARKER|ACCEPTANCE OF|INSTALL(ATION)? OF|REPORT TITLE|'
                             r'MARKER\s*:)', line):
                continue
            if re.search(r'(?i)\b(BASED\s+ON|copied\s+from|previous|predecessor|ancestor)\b', line):
                continue
            for tok in re.findall(r'[0-9a-fA-F]{7}', line):
                low = tok.lower()
                if _commitish(low) and low not in stem_commits:
                    faults.append("line %d: a PRINTED marker or title names commit %s while the file "
                                  "is named for %s - the document lies about itself. A reader will "
                                  "match the marker against the filename and spend a move on it. "
                                  "Rename the printed text, not the file" % (line_no, tok,
                                  '/'.join(sorted(stem_commits))))
                    break
            else:
                continue
            break

    # --- a probe may not claim it descends from itself ----------------------------
    # Measured cost, 2026-10-10, TWICE in one day: a search-and-replace of the commit token across
    # the whole file also hit the "SHAPE FROM"/"BASED ON" line, so the new probe named ITSELF as its
    # own predecessor. The provenance line is the one thing a reader uses to find what the
    # expectations were inherited from; a self-reference destroys exactly that. Attention did not
    # catch it the second time either, which is why it is a gate and not a note.
    stem = os.path.basename(path)
    for line_no, line in enumerate(txt.splitlines(), 1):
        if not re.search(r'(?i)(SHAPE\s+FROM|BASED\s+ON)', line):
            continue
        if stem in line:
            faults.append("line %d: the provenance line names THIS file (%s) as its own "
                          "predecessor - a search-and-replace across the file hit it. Name the "
                          "probe it was actually built from, or a reader cannot find where the "
                          "expectations came from" % (line_no, stem))
        break

    # --- a probe that WRITES to production must read the bus first ----------------
    # Measured cost, 2026-10-10: the coordinator revoked the blessing at 10:15Z after the operator
    # said "one rollout, not piecemeal". I had read the blessing at 09:53Z and never re-read the
    # inbox; the package was built at 10:28Z and installed on production at 10:52Z - against the
    # operator's own decision. The result happened to be green, which is luck, not order.
    # So: any probe that invokes the updater must read the LAST letter of its own inbox and refuse
    # to continue if that letter revokes or stops. A rule in a role body is a promise; this is a gate.
    if re.search(r'(?i)Update-RTMView\.ps1', txt) and re.search(r'(?i)(powershell|pwsh)[^\n]*-File\s+\$updaterPath', txt):
        reads_bus = re.search(r'(?i)\.coord[\\/]inbox[\\/]devops\.md', txt)
        if not reads_bus:
            faults.append("this probe runs Update-RTMView on production but never reads "
                          ".coord/inbox/devops.md - on 2026-10-10 a flight was installed four hours "
                          "after its blessing had been revoked, because the inbox was not re-read "
                          "before the write. A probe that writes to production reads its last "
                          "letter first and stops on a revocation")

    # --- a watching window must be wider than the thing it watches ---------------
    # A probe that waits for RTMTwilio_1 to come back decides "did it return" from a FIXED number of
    # sleeps. If that window is narrower than the slowest return ever measured, the probe cannot tell
    # "it never came up" from "it comes up slower than I watched" - a predicate weaker than its own
    # question, which reads as a red that is not there.
    # Measured cost, 2026-10-05: the install probe sampled 3 times 20 s apart (40 s) and printed
    # Stopped three times; the adapter actually returned at 278 s, 209 s of which were AFTER the
    # engine was already Running. The operator was told the adapter was down. It was not.
    # The floor is therefore the measured worst case plus room: 300 s.
    ADAPTER_FLOOR_SECONDS = 300
    if re.search(r'RTMTwilio_1', txt):
        sleeps = [int(m) for m in re.findall(r'(?i)Start-Sleep\s+-Seconds\s+(\d+)', txt)]
        # A wait bounded by a DEADLINE is the form this gate asked for in the first place: the probe
        # polls on a short sleep but stops at a wall-clock limit, so the literals say nothing about
        # the window. Measuring the literals there would paint the CORRECT shape red - the same
        # false-red this gate exists to prevent. So a deadline of at least the floor satisfies it.
        deadlines = [int(m) for m in re.findall(r'(?i)AddSeconds\(\s*(\d+)\s*\)', txt)]
        if deadlines and max(deadlines) >= ADAPTER_FLOOR_SECONDS:
            sleeps = []
            notes.append("the adapter wait is bounded by a deadline of %d s, not by sleep literals - "
                         "window accepted" % max(deadlines))
        if sleeps:
            window = sum(sleeps)
            if window < ADAPTER_FLOOR_SECONDS:
                faults.append("the probe waits for RTMTwilio_1 and the sleep LITERALS in its text "
                              "add up to %d s (%s). That is a LOWER BOUND, not the window: a sleep "
                              "inside a loop runs more than once - the 2026-10-05 install probe shows "
                              "20 s here and waited 40 s. The slowest measured return is 278 s "
                              "[234_20261005_081231_install-e7eb243.txt: Stopped 08:56:17, Running "
                              "09:00:55], so this window cannot tell 'never came up' from 'slower "
                              "than I watched'. Raise the literals past %d s, or key the wait to the "
                              "SCM event instead of counting seconds. If the real window already "
                              "exceeds that because of a loop, say so in the probe's own text - a "
                              "number a reader cannot see is not a measurement"
                              % (window, '+'.join(str(s) for s in sleeps), ADAPTER_FLOOR_SECONDS))

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
