# .coord/inbox/ — directed message channel (mailbox)

Spec: skill session-coord §11. Removes operator copy-paste of message BODIES.
The operator still triggers turns (sessions do not poll) — see §11.

Files:
- `<slug>.md`        — messages TO that session (directives from coordinator, questions from peers)
- `coordinator.md`   — questions/escalations TO the coordinator, from any session

Format (append-only, one block per message, Python+fsync):

    ## <UTC> | from: <slug> | to: <slug>
    <message body — directive, question, status, handoff>
    ---

Read your inbox at the start of every turn (best-effort) and on the explicit
operator command `коорд: входящие` (reliable trigger). Mark handled messages by
appending a `> handled <UTC> by <slug>` line — never delete (append-only audit).
