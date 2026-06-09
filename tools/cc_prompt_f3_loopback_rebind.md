# CC Task — F-3 fix: RTM hub LOOPBACK-rebind (Security compensator, 234 deploy-blocking)

> Session devops-2-0607. Closes Security finding F-3 (RTM SignalR hub reachable on all interfaces). Real fix per
> coordinator (§34 server-to-server, RTM+Shell co-located all-in-one on 234): bind the RTM hub to 127.0.0.1 so it is
> UNREACHABLE from the browser/network. Replaces the failed firewall compensator.
> Root cause (verified): RTM/RTM/appsettings.json → Kestrel:Endpoints:Http:Url = "http://*:8088" (`*` = all ifaces → `::` listen on 234). It is in APPSETTINGS (deploy-config), NOT hardcoded in Program.cs.

## 0. §0.6a integrity FIRST. 0b. §40 reads. Standard preamble.
## Sync (§42.6) slug devops-2-0607. Claims (file-mode): `RTM/RTM/appsettings.json`, `deploy/Apply-Server45Upgrade.ps1`.
- S1 marker barrier; S2 coord_check_claims; S3 commit.lock; S4 cc_post_commit.sh.
## §37 NO push. §0.3 Python+fsync (Edit BANNED). §35 PS1 = BOM+CRLF; appsettings.json stays UTF-8 (no BOM).

---

# FILE A — RTM/RTM/appsettings.json  (rtm:)
Change Kestrel:Endpoints:Http:Url from `"http://*:8088"` to `"http://127.0.0.1:8088"` (loopback only).
- Read-modify-write JSON (preserve every other key/section — RTM:TenantId, ConnectionStrings, Logging, etc.). Do NOT reformat the whole file.
- This makes FRESH packages ship loopback-bound by default.

# FILE B — deploy/Apply-Server45Upgrade.ps1  (deploy:) — make the deployed server loopback + keep the relay working
Two idempotent steps in the config-wiring phase (the one that already patches Shell appsettings):

## B1 — assert/patch the DEPLOYED RTM appsettings bind = loopback
Read the deployed RTM appsettings.json; if Kestrel:Endpoints:Http:Url != "http://127.0.0.1:8088" → set it (read-modify-write, preserve other keys). Covers servers whose shipped appsettings still has `*`. Log old→new.

## B2 — keep Shell→RTM relay working (loopback URL) — REQUIRED or the rebind breaks the relay
The Shell reaches the hub via TenantSettings.SignalRConnectionUrl (§6.2; hub path = "/signalr", RTM Program.cs:112). After rebinding RTM to loopback, this MUST be the loopback URL or RtmRelayService can't connect.
- Read RTM:TenantId from the deployed RTM appsettings.json.
- UPDATE tenant_settings SET "SignalRConnectionUrl" = 'http://127.0.0.1:8088/signalr' WHERE "TenantId" = <that id> ; run as the app/catowner (parameterised, EAP=Continue + $LASTEXITCODE gate). Idempotent.
- Log the set value. If RTM:TenantId is empty → WARN + skip (do not guess), and surface in the report so the operator sets SignalRConnectionUrl via the Tenant Settings UI.

(Note: because RTM+Shell are co-located on 234, 127.0.0.1 is correct for the Shell→RTM hop. The browser never touches the hub — §34 RtmRelay. This is what actually makes the hub external-unreachable, independent of the permissive firewall.)

---

## Self-tests
- FILE A: the deployed/repo appsettings parses as JSON; Url == "http://127.0.0.1:8088"; RTM:TenantId + ConnectionStrings still present (no key loss).
- FILE B: AST 0 err; greps — B1 read-modify-write asserts 127.0.0.1:8088; B2 UPDATE tenant_settings SignalRConnectionUrl = loopback /signalr, parameterised, reads RTM:TenantId; BOM ok on PS1.
- grep RTM/RTM/appsettings.json: no remaining `http://*:` or `0.0.0.0` bind.

## Verification note for the operator (post-deploy, records the F-3 closure)
After deploy on 234: `Get-NetTCPConnection -State Listen -OwningProcess <RTMService pid>` must show LocalAddress 127.0.0.1 (NOT `::`/0.0.0.0) for 8088 → that is the F-3 proof. Append to C:\RTMView-Ops\output\f3_isolation_proof.txt.

## Commit — TWO commits (§39.3)
COMMIT 1 rtm:    `git add RTM/RTM/appsettings.json` → `git commit -m "rtm: bind SignalR hub to 127.0.0.1 (F-3 loopback compensator)"`
COMMIT 2 deploy: `git add deploy/Apply-Server45Upgrade.ps1` → `git commit -m "deploy: assert RTM loopback bind + set Shell SignalRConnectionUrl to loopback (F-3)"`
pre-commit-check.sh→0 ; commit.lock both ; §0.6 verify ; cc_post_commit.sh per commit ; HEAD re-sync. NO push.

## Report back
FILE A new Url + key-preservation proof ; FILE B B1/B2 greps + RTM:TenantId-empty handling ; no remaining `*`/0.0.0.0 bind ; BOM ; 2 hashes. NO push. (Then Security re-ACK on F-3 = hub now loopback.)
