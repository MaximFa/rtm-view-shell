---
name: finesse-expert
description: "Deep expert knowledge of Cisco Finesse architecture, REST API, XMPP Notification Service, agent state machine, call/dialog model, and integration patterns for UCCE and UCCX. Trigger whenever the user asks anything about Finesse API endpoints, XMPP events, dialog/participant states, agent state transitions, CTI event mappings, Finesse authentication, BOSH/WebSocket connection, FinesseRestClient, FinesseEventListener, FinesseStatePump, supervisor call control (silent monitor, barge, whisper), call transfer/conference flows, Finesse 12.x specifics, UCCE vs UCCX behavioral differences, Finesse error codes, wrap-up reasons, reason codes, phonebooks, queue statistics, Finesse gadget migration, or any integration issue involving Cisco Finesse. Also trigger for questions about why Finesse sends a particular event, how hold works in Finesse, what state the agent enters after transfer, or how to subscribe to XMPP notifications."
---

# Cisco Finesse Expert

You are a deep expert in Cisco Finesse. When this skill is loaded, answer questions with precise knowledge of the following domains. Cross-reference sections as needed — the call model, state machine, and XMPP events are tightly coupled.

---

## 1. Architecture

### Signal flow (UCCX/UCCE)

```
Browser/SPA
  │  HTTPS REST     ←→   Finesse Tomcat (port 8445/443)
  │  XMPP/BOSH/WS  ←→   Finesse Notification Service (OpenFire, port 7443)
  │
Finesse Tomcat
  │  CTI (port 12018)  ←→  CTI Server / UCCX Engine
  │  JTAPI             ←→  CUCM (call control)
  │  AXL / SOAP        ←→  CUCM (provisioning)
  │  XMPP              →   OpenFire Notification Service
  │  Hibernate         ←→  Finesse DB
  │
OpenFire (Notification Service)
  │  XMPP/BOSH long-poll  →  Agent browsers (30-second BOSH cycle)
```

**Key processes on Finesse server:**
- `Finesse Tomcat` — REST API WAR (`finesse.war`). The Finesse WebServices logs here are the primary troubleshooting log.
- `OpenFire` — XMPP notification service. Separate process. Receives XMPP messages from Tomcat, delivers them to subscribed clients via BOSH/WebSocket.
- `Apache Shindig` — OpenSocial container for legacy gadget hosting. Proxies REST calls and gadget content. Not relevant for pure REST/XMPP third-party clients.

**BOSH transport:** Client keeps a persistent HTTP long-poll to `https://<FQDN>:7443/http-bind`. Server holds the request up to 30 seconds; replies with XMPP event if one arrives, otherwise replies with empty to let the client re-poll. WebSocket is also supported from Finesse 12.x (same port 7443, path `/ws`).

**Failover (UCCX):** Finesse sends a `systeminfo` API response telling the client the node is down. Client then redirects to the standby node. Three TLS certificates must be accepted: notification service cert (active node), notification service cert (standby node), Finesse service cert (standby node).

---

## 2. Authentication

- **Finesse REST API:** HTTP Basic Auth (Base64 `username:password`) on every request. No session tokens in REST.
- **XMPP login:** SASL PLAIN with the same Finesse credentials. JID format: `username@xmpp-domain` (get `xmppDomain` from SystemInfo API).
- **Finesse credentials:** Per-agent (each agent uses their own extension + Finesse password). Service accounts exist for admin operations but agents log in with their own credentials.
- **HTTPS only:** Port 8445 (direct) or 443 (via load balancer). Plain HTTP connections are rejected.
- **SystemInfo endpoint** (unauthenticated): `GET https://<FQDN>/finesse/api/SystemInfo` — returns `xmppDomain`, `xmppPubSubDomain`, cluster status, active/standby node. Call this before XMPP login.

```xml
<SystemInfo>
  <status>IN_SERVICE</status>
  <xmppDomain>finesse.example.com</xmppDomain>
  <xmppPubSubDomain>pubsub.finesse.example.com</xmppPubSubDomain>
</SystemInfo>
```

---

## 3. REST API — Core Resources

### 3.1 Request/Response semantics

| Method | Behavior |
|--------|----------|
| GET | Synchronous — response body contains full object |
| PUT / POST | **Asynchronous** — response is `200 OK` or `202 Accepted` with empty body; actual result arrives as an XMPP notification |
| DELETE | Asynchronous — result via XMPP notification |

If a PUT/POST fails Finesse's internal validation → synchronous error response (body contains `<ApiErrors>`). If it fails at CTI layer → async XMPP error notification with error code.

Use `RequestId` header (arbitrary unique string) to correlate your PUT/POST with the resulting XMPP notification.

### 3.2 User resource

Base URI: `https://<FQDN>/finesse/api/User/<agentId>`

| Operation | Method | URI | Body |
|-----------|--------|-----|------|
| Get user info | GET | `/finesse/api/User/{id}` | — |
| Agent login | PUT | `/finesse/api/User/{id}` | `<User><state>LOGIN</state><extension>{ext}</extension></User>` |
| Change state | PUT | `/finesse/api/User/{id}` | `<User><state>READY</state></User>` |
| Change state with reason | PUT | `/finesse/api/User/{id}` | `<User><state>NOT_READY</state><reasonCodeId>{id}</reasonCodeId></User>` |
| Agent logout | PUT | `/finesse/api/User/{id}` | `<User><state>LOGOUT</state><reasonCodeId>{id}</reasonCodeId></User>` |
| Get dialogs | GET | `/finesse/api/User/{id}/Dialogs` | — |
| Make outbound call | POST | `/finesse/api/User/{id}/Dialogs` | `<Dialog><requestedAction>MAKE_CALL</requestedAction><toAddress>{number}</toAddress><fromAddress>{ext}</fromAddress></Dialog>` |
| Get queue stats | GET | `/finesse/api/User/{id}/Queues` | — |
| Get wrap-up reasons | GET | `/finesse/api/User/{id}/WrapUpReasons` | — |
| Get not-ready reason codes | GET | `/finesse/api/User/{id}/NotReadyReasonCodes` | — |
| Silent monitor (supervisor) | POST | `/finesse/api/User/{supervisorId}/Dialogs` | `<Dialog><requestedAction>SILENT_MONITOR</requestedAction><targetMediaAddress>{agentExt}</targetMediaAddress></Dialog>` |
| Barge in (supervisor) | POST | `/finesse/api/User/{supervisorId}/Dialogs` | `<Dialog><requestedAction>BARGE_IN</requestedAction><targetMediaAddress>{agentExt}</targetMediaAddress><associatedDialogUri>{smDialogUri}</associatedDialogUri></Dialog>` |
| Force agent state change (supervisor) | PUT | `/finesse/api/User/{agentId}` | `<User><state>NOT_READY</state></User>` |

**Security constraints:** Agents can only act on their own User object. Supervisors can act on agents in their own team only.

### 3.3 Dialog resource

Base URI: `https://<FQDN>/finesse/api/Dialog/<dialogId>`

| Operation | Method | URI | Body (key fields) |
|-----------|--------|-----|--------------------|
| Get dialog | GET | `/finesse/api/Dialog/{id}` | — |
| Answer call | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>ANSWER</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Hold call | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>HOLD</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Retrieve held call | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>RETRIEVE</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Drop (release) | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>DROP</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Start consult call | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>CONSULT_CALL</requestedAction><mediaAddress>{ext}</mediaAddress><toAddress>{dest}</toAddress></Dialog>` |
| Complete transfer | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>TRANSFER</requestedAction><mediaAddress>{ext}</mediaAddress><toAddress>{otherDialogId}</toAddress></Dialog>` |
| Single-step transfer (blind) | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>TRANSFER_SST</requestedAction><mediaAddress>{ext}</mediaAddress><toAddress>{dest}</toAddress></Dialog>` |
| Complete conference | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>CONFERENCE</requestedAction><mediaAddress>{ext}</mediaAddress><toAddress>{otherDialogId}</toAddress></Dialog>` |
| Send DTMF | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>SEND_DTMF</requestedAction><mediaAddress>{ext}</mediaAddress><dtmfDigits>{digits}</dtmfDigits></Dialog>` |
| Update call data (ECC vars) | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>UPDATE_CALL_DATA</requestedAction><mediaAddress>{ext}</mediaAddress><mediaProperties>...</mediaProperties></Dialog>` |
| Accept UCCX task | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>ACCEPT</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Reject UCCX task | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>REJECT</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |
| Close UCCX task | PUT | `/finesse/api/Dialog/{id}` | `<Dialog><requestedAction>CLOSE</requestedAction><mediaAddress>{ext}</mediaAddress></Dialog>` |

**Available actions** are listed in the participant's `<actions>` array in the Dialog notification. Only actions listed there are allowed for that participant at that moment. Attempting an action not in the list returns an error.

---

## 4. Agent State Machine

### 4.1 UCCE agent states

States an agent can **set via API**: `LOGIN`, `READY`, `NOT_READY`, `LOGOUT`

States the **system sets** (cannot be set via API): `RESERVED`, `RESERVED_OUTBOUND`, `RESERVED_OUTBOUND_PREVIEW`, `TALKING`, `HOLD`, `WORK`, `WORK_READY`, `UNKNOWN`

**Key transitions (UCCE):**

| From | To | Trigger |
|------|----|---------|
| LOGOUT | LOGIN | Agent initiates login (transient state) |
| LOGIN | NOT_READY | After successful login |
| NOT_READY | READY | Agent makes self available |
| NOT_READY | LOGOUT | Agent signs out |
| NOT_READY | NOT_READY | Agent changes reason code |
| NOT_READY | TALKING | Agent places outbound call while NOT_READY |
| READY | RESERVED | Inbound call arrives at agent's extension |
| READY | RESERVED_OUTBOUND | Progressive/Predictive outbound campaign reserves agent |
| READY | RESERVED_OUTBOUND_PREVIEW | Preview/Direct Preview outbound reserves agent |
| READY | NOT_READY | Agent makes self unavailable |
| RESERVED | TALKING | Agent answers the call |
| RESERVED | READY | Call was abandoned before agent answered |
| TALKING | HOLD | Agent puts call on hold |
| TALKING | WORK | Call ends; wrap-up required; agent had pending NOT_READY |
| TALKING | WORK_READY | Call ends; wrap-up required; agent was in READY before call |
| TALKING | NOT_READY | Call ends; no wrap-up; agent was in NOT_READY |
| TALKING | READY | Call ends; no wrap-up; agent was in READY |
| HOLD | TALKING | Agent retrieves held call |
| HOLD → WORK / WORK_READY / NOT_READY / READY | | Call dropped while on hold; same logic as TALKING transitions |
| WORK | NOT_READY | Agent leaves wrap-up to NOT_READY (or timer expires) |
| WORK | READY | Agent manually leaves wrap-up to READY |
| WORK_READY | READY | Agent leaves wrap-up (or timer expires) → READY |
| WORK_READY | NOT_READY | Agent manually leaves wrap-up → NOT_READY |

**Pending state changes:** While in TALKING, HOLD, RESERVED, OUTBOUND, or PREVIEW states, a PUT to change state creates a *pending* state — stored on server, applied after call ends. Only one pending state is allowed at a time.

**Supervisor force-change restrictions (UCCE):**
- Can set READY, NOT_READY, or LOGOUT on agents in their team.
- LOGOUT is valid from any active state.
- NOT_READY: valid from READY, WORK, WORK_READY only.
- Supervisor-initiated NOT_READY → reason code 999 sent to CTI (system hard-coded, cannot be overridden).

### 4.2 UCCX agent states

Simplified state machine. Notable differences from UCCE:
- Agent does NOT transition to HOLD state when holding a call — stays in TALKING.
- Non-ICD calls do not change agent state at all.
- Agent cannot set pending READY while on a call.
- WORK_READY state does not exist.
- Agent can LOGOUT directly from READY (not only from NOT_READY).
- Supervisor-initiated NOT_READY → reason code 33.
- Outbound preview: state changes only via Dialog ACCEPT/CLOSE/REJECT, not via state PUT.

---

## 5. Call Model — Dialog and Participant States

### 5.1 Dialog states

| State | Meaning |
|-------|---------|
| `INITIATING` | Call is being set up (BEGIN_CALL_EVENT received) |
| `INITIATED` | Caller has dialed the number; ringing destination |
| `ALERTING` | Call is ringing at destination |
| `ACTIVE` | Call is connected (at least one participant active) |
| `DROPPED` | Call has ended; Dialog about to be deleted |
| `FAILED` | Call failed (BUSY, BAD_DESTINATION, OTHER) |

### 5.2 Participant states

| State | Meaning |
|-------|---------|
| `INITIATING` | Participant is initiating the call leg |
| `INITIATED` | Participant has dialed; call is proceeding |
| `ALERTING` | Call is ringing at this participant's device |
| `ACTIVE` | Participant is connected to the call |
| `HELD` | Participant's leg is on hold |
| `DROPPED` | Participant has left the call |
| `FAILED` | Participant's leg failed (see `stateCause`) |

`stateCause` values for FAILED: `BUSY`, `BAD_DESTINATION`, `OTHER`

### 5.3 CTI event → Dialog/Participant state mapping

**Incoming call (ICD):**

| Scenario | Dialog State | Agent Participant | Caller Participant |
|----------|-------------|-------------------|-------------------|
| Call starts (BEGIN_CALL) | INITIATING | (not yet) | INITIATING |
| Call arrives at agent (CALL_DELIVERED) | ALERTING | ALERTING | INITIATED |
| Agent answers (CALL_ESTABLISHED) | ACTIVE | ACTIVE | ACTIVE |
| Caller drops (CALL_CONNECTION_CLEARED) | ACTIVE | ACTIVE | DROPPED |
| Agent dropped (CALL_CONNECTION_CLEARED) | DROPPED | DROPPED | DROPPED |
| Dialog removed (END_CALL_EVENT) | DROPPED | DROPPED | DROPPED |

**Outgoing call:**

| Scenario | Dialog State | Caller (Agent) | Recipient |
|----------|-------------|----------------|-----------|
| Call starts | INITIATING | INITIATING | (not yet) |
| Agent dials | INITIATED | INITIATED | (not yet) |
| Destination busy | FAILED | FAILED | (not yet) |
| Ringing at destination | ALERTING | INITIATED | ALERTING |
| Recipient answers | ACTIVE | ACTIVE | ACTIVE |

**Hold/Retrieve:**

| Scenario | Dialog State | Agent | Caller |
|----------|-------------|-------|--------|
| Agent holds (CALL_HELD) | ACTIVE | HELD | ACTIVE |
| Both hold | ACTIVE | HELD | HELD |
| Agent retrieves (CALL_RETRIEVED) | ACTIVE | ACTIVE | HELD |

**Consult Transfer flow:**

1. Agent A holds original call → Agent A: HELD on original call
2. Agent A dials consult → new Dialog INITIATING
3. Consult ringing at Agent B → Consult Dialog: ALERTING; Agent B: ALERTING
4. Agent B answers → Consult Dialog: ACTIVE; both participants ACTIVE
5. Agent A transfers → original Dialog: DROPPED for Agent A; Agent B gets POST on original Dialog with Agent B as ACTIVE participant; consult Dialog: DROPPED

`secondaryId` on the surviving Dialog contains the dropped Dialog's ID. Supported from Finesse 11.6(1) ES1 for UCCE; UCCE also populates it for direct transfers.

**Silent Monitor:**

- Supervisor POSTs `SILENT_MONITOR` → creates a separate Dialog for supervisor (type: SILENT_MONITOR)
- Agent sees a *passive* second Dialog (they are a participant with no allowed actions)
- Dialog state: INITIATING → INITIATED → ALERTING → ACTIVE
- Supervisor's participant has no actions (read-only monitoring)

**Barge-in sequence:**

1. Finesse drops the silent monitor Dialog
2. Unified CCE puts the original call on HOLD (Agent A: HELD)
3. UCCx/UCCe generates a consult call, dials supervisor's extension
4. Agent A receives consult call (INITIATED), Supervisor receives (ALERTING)
5. UCCe answers on supervisor's behalf, converts original call to conference
6. Agent A returns to ACTIVE on original call; Supervisor is ACTIVE; call type = 15 (Conference)

---

## 6. XMPP Notification Service

### 6.1 Connection

1. GET `https://<FQDN>/finesse/api/SystemInfo` → get `xmppDomain` and `xmppPubSubDomain`
2. Connect XMPP over BOSH: `https://<FQDN>:7443/http-bind` (or WebSocket at `wss://<FQDN>:7443/ws`)
3. SASL PLAIN auth with agent credentials (JID: `username@xmppDomain`)
4. Send presence stanza with priority ≥ 0 immediately after auth
5. Enable whitespace pings (Finesse uses 10s interval, 2 retries) — Finesse depends on this to detect disconnected clients and trigger auto-logout

Stream management (`<sm xmlns='urn:ietf:params:xml:ns:xmpp-sm3'>`) is NOT supported.

### 6.2 Auto-subscribed nodes

Every agent is automatically subscribed to:
- `/finesse/api/User/{agentId}` — user/state events
- `/finesse/api/User/{agentId}/Dialogs` — dialog events (calls)
- `/finesse/api/User/{agentId}/Media/{mrd-id}` — media channel state (UCCX multichannel)
- `/finesse/api/SystemInfo` — system status / failover events

### 6.3 Explicit subscriptions

Subscribe to a team feed (supervisor):
```xml
<iq type='set' from='supervisor@finesse.example.com'
    to='pubsub.finesse.example.com' id='sub1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <subscribe node='/finesse/api/Team/{teamId}/Users'
               jid='supervisor@finesse.example.com/resource'/>
  </pubsub>
</iq>
```

Always use **full JID** (with `/resource`) for explicit subscriptions to avoid leaking subscriptions. Unsubscribe before disconnecting — orphaned subscriptions persist in OpenFire.

Common nodes for explicit subscription:
- `/finesse/api/Team/{teamId}/Users` — all agent state changes on the team
- `/finesse/api/Queue/{queueId}` — queue statistics
- `/finesse/api/Dialog/{id}` — specific dialog events

### 6.4 Notification payload format

All notifications arrive as XMPP `<message>` stanzas containing a `<Update>` XML element.

**Dialog added/removed (POST or DELETE):**
```xml
<Update>
  <data>
    <dialogs>
      <Dialog>
        <id>2130715746</id>
        <state>INITIATING</state>
        <mediaType>Voice</mediaType>
        <fromAddress>1001</fromAddress>
        <toAddress>5000</toAddress>
        <participants>
          <Participant>
            <mediaAddress>1001</mediaAddress>
            <state>INITIATING</state>
            <actions><action>DROP</action></actions>
            <startTime>2024-01-15T10:30:00.000Z</startTime>
            <stateChangeTime>2024-01-15T10:30:00.000Z</stateChangeTime>
          </Participant>
        </participants>
        <mediaProperties>
          <DNIS>5000</DNIS>
          <callType>INBOUND_ACD</callType>
          <queueNumber>5022</queueNumber>
          <queueName>Support Queue</queueName>
          <callvariables>
            <CallVariable><name>callVariable1</name><value>value1</value></CallVariable>
          </callvariables>
        </mediaProperties>
        <uri>/finesse/api/Dialog/2130715746</uri>
      </Dialog>
    </dialogs>
  </data>
  <event>POST</event>
  <requestId>correlation-id-from-original-request</requestId>
  <source>/finesse/api/User/1001/Dialogs</source>
</Update>
```

**Dialog modified (PUT):**
```xml
<Update>
  <data>
    <dialog><!-- full Dialog object --></dialog>
  </data>
  <event>PUT</event>
  <source>/finesse/api/Dialog/2130715746</source>
</Update>
```

**User state event:**
```xml
<Update>
  <data>
    <user>
      <state>TALKING</state>
      <reasonCode>...</reasonCode>
      <pendingState>NOT_READY</pendingState>
      <!-- full User object -->
    </user>
  </data>
  <event>PUT</event>
  <source>/finesse/api/User/1001</source>
</Update>
```

**Node** for user events: `/finesse/api/User/{id}`
**Node** for dialog events: `/finesse/api/User/{id}/Dialogs`
**Source** field distinguishes event origin: if `source` is `/finesse/api/Dialog/{id}` within a Dialogs notification, the Dialog within the `<dialogs>` collection was modified.

### 6.5 CTI error notifications (async)

When a PUT/POST fails at CTI layer, Finesse sends an XMPP error event:
```xml
<Update>
  <data>
    <apiErrors>
      <apiError>
        <errorType>Invalid State</errorType>
        <errorData>257</errorData>
        <errorMessage>CF_INVALID_PASSWORD_SPECIFIED</errorMessage>
      </apiError>
    </apiErrors>
  </data>
  <event>ERROR</event>
  <requestId>your-correlation-id</requestId>
  <source>/finesse/api/User/1001</source>
</Update>
```

---

## 7. Integration Patterns for This Project

### 7.1 FinesseRestClient

Thin HTTP wrapper using `HttpClientFactory` + Polly:
- **Retry policy:** 2 retries with exponential back-off (500ms, 1s) on 5xx and network errors
- **Circuit breaker:** 3 failures in 30s → open → fallback `{available: false, reason: "gateway_error"}`
- **Auth:** Per-request Basic Auth header from encrypted credentials (never cached in memory longer than request lifetime)
- **RequestId:** Generate `Guid.NewGuid().ToString()` per request; attach as HTTP header `RequestId`; track in Redis `finesse:pending:{requestId}` with TTL = 30s for correlation

### 7.2 FinesseEventListener

Long-running `IHostedService` managing the XMPP connection:
- On start: connect BOSH, auth, send presence, subscribe to team nodes
- Parse incoming `<Update>` XML → map to domain events → publish to internal event bus (MediatR)
- **Reconnect:** Exponential back-off (1s → 2s → 4s → … → 60s max)
- **On reconnect:** Re-subscribe all active agent subscriptions; poll REST `GET /finesse/api/User/{ext}` for current state of each active agent (reconciliation, since events during outage are lost)
- **Heartbeat detection:** Finesse disconnects XMPP silently if whitespace pings fail. Add a server-side timer: if no event received within 90s (3× the 30s BOSH cycle), treat as disconnect and reconnect.
- **Silent disconnect pitfall:** OpenFire can drop BOSH connections without a clean close frame. Do not rely only on XMPP ping. Monitor `LastHeartbeatAt` in Redis independently.

### 7.3 FinesseStatePump

Bridges `IFinesseGateway` events to SignalR:
- Maps `<Update>` XML to domain events (`AgentStateChangedEvent`, `CallUpdatedEvent`, etc.)
- Uses `FinesseMapper.cs` for string → enum mapping
- Publishes to `AgentHub` (per-agent connections) and `SupervisorHub` (team-level fan-out)
- Unknown Finesse state strings → `AgentState.Unknown` + Serilog warning (never throw)

### 7.4 State mapping (FinesseMapper)

| Finesse string | Domain `AgentState` |
|----------------|---------------------|
| `READY` | Ready |
| `NOT_READY` | NotReady |
| `TALKING` | OnCall |
| `HOLD` | OnHold |
| `WORK` | WrapUp |
| `WORK_READY` | WrapUp |
| `RESERVED` | Reserved |
| `RESERVED_OUTBOUND` | Reserved |
| `RESERVED_OUTBOUND_PREVIEW` | Reserved |
| `LOGIN` | LoggingIn |
| `LOGOUT` | LoggedOut |
| `UNKNOWN` | Unknown |
| *(anything else)* | Unknown + log warning |

**[FINESSE-01]** Never expose raw Finesse state strings to frontend.

---

## 8. UCCE vs UCCX Key Differences

| Feature | UCCE (standalone Finesse) | UCCX (co-resident Finesse) |
|---------|--------------------------|---------------------------|
| HOLD state on agent | Yes (agent transitions to HOLD) | No (agent stays in TALKING) |
| Non-ICD call state change | Agent transitions to TALKING | Agent stays in NOT_READY |
| WORK_READY state | Yes | No |
| Pending READY while on call | Allowed | Not allowed (error 265) |
| LOGOUT from READY | No (must be NOT_READY first) | Yes |
| Supervisor forced NOT_READY reason code | 999 | 33 |
| Outbound preview state exit | Via state PUT (READY/NOT_READY) | Via Dialog ACCEPT/CLOSE/REJECT only |
| Chat/Email contacts | Separate UCCX REST API (`/uccxwallboard/rest/`) | Same |
| Multichannel MRD | Via Media API | Via Media API |
| Queue stats API | `/finesse/api/Queue` | `/finesse/api/Queue` + UCCX wallboard REST |

---

## 9. Common Error Codes

| Code | Message | Meaning |
|------|---------|---------|
| 257 | CF_INVALID_PASSWORD_SPECIFIED | Wrong credentials or attempting forbidden state transition |
| 265 | CF_INVALID_AGENT_WORKMODE | Invalid state transition for wrap-up mode (UCCX) |
| 33 | CF_RESOURCE_BUSY | Resource locked; cannot change state now |
| 1010 | CF_INVALID_PARAMETER | Invalid parameter (UCCX generic) |
| 400 (sync) | Parameter Missing | Required XML element absent in request body |
| 401 | Unauthorized | Bad credentials or supervisor acting outside team |
| 404 | Not Found | Agent/dialog doesn't exist |
| 503 | Service Unavailable | CTI server unreachable; circuit breaker should activate |

---

## 10. mediaProperties Fields

Key fields in `<mediaProperties>` within a Dialog notification:

| Field | Description |
|-------|-------------|
| `DNIS` | Dialed Number Identification Service — the number the caller dialed |
| `callType` | `INBOUND_ACD`, `AGENT_INSIDE`, `CONSULT`, `OUTBOUND`, `SUPERVISOR_MONITOR`, `BARGE` |
| `callvariables` | ECC variables (callVariable1–callVariable10, userToUser, BAdata) |
| `queueNumber` | Finesse queue ID |
| `queueName` | Display name of the queue |
| `dialedNumber` | Number dialed for outbound calls |
| `outboundClassification` | For Outbound Option: `VOICE`, `FAX`, `ANS_MACHINE`, `INVALID`, `DO_NOT_CALL`, `BUSY` |
| `callKeyCallId` / `callKeySequenceNum` / `callKeyPrefix` | Unique call identifier for correlation with UCCE DB |
| `mediaId` | MRD (Media Routing Domain) ID; 1 = voice in UCCX |

---

## 11. Caching and Performance

- Finesse webproxy caches: `ChatConfig`, `ECCVariableConfig`, `MediaDomain`, `TeamResource` (team-level)
- To bypass server cache (debugging only): add `bypassServerCache=true` query param — degrades performance
- CLI to clear: `utils webproxy cache clear rest`
- Queue snapshots: push every 5s per active supervisor connection (our architecture)
- Agent events: event-driven (push on state change), not polled

---

## 12. Gadget Migration Reference

Legacy Finesse gadgets are OpenSocial XML descriptors hosted in `shindig`. Gadget APIs (`finesse.restservices.*`) wrap the same REST endpoints documented above. When migrating:
- Map gadget `finesse.restservices.User` methods → our `FinesseRestClient` REST calls
- Map gadget `dialog.requestAction(ext, 'HOLD', ...)` → `PUT /finesse/api/Dialog/{id}` with `<requestedAction>HOLD</requestedAction>`
- XMPP event handling in gadgets uses `finesse.restservices.Dialog.addHandler('change', ...)` → our `FinesseEventListener` XMPP subscription
- Document gadget IDs and feature mapping in `docs/finesse-gadget-inventory.md` before removing

---

## References

- Cisco DevNet Finesse: https://developer.cisco.com/docs/finesse/
- User resource: https://developer.cisco.com/docs/finesse/rest-services-user/
- Dialog resource: https://developer.cisco.com/docs/finesse/rest-services-dialog/
- Real-time events: https://developer.cisco.com/docs/finesse/real-time-events/
- Subscription management: https://developer.cisco.com/docs/finesse/subscription-management/
- CTI event mappings: https://developer.cisco.com/docs/finesse/cti-event-mappings-for-dialog-and-participant-states/
- Agent state changes: https://developer.cisco.com/docs/finesse/user—change-agent-state/
- Dialog notifications: https://developer.cisco.com/docs/finesse/dialog-notification/
- Dialog API parameters: https://developer.cisco.com/docs/finesse/dialog-api-parameters/
- UCCX Finesse architecture deep dive: https://www.cisco.com/c/en/us/support/docs/contact-center/finesse/221598-understand-uccx-finesse-architecture-dee.html
       