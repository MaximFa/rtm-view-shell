---
name: feedback-ask-questions-text-only
description: Max prefers clarifying questions as plain text; the AskUserQuestion tool hangs
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dab62ab9-93dc-4f3e-9e26-fdaaa3f53baa
---

Ask Max clarifying/scoping questions **as plain text in the chat message**, never via the built-in AskUserQuestion multiple-choice tool.

**Why:** The AskUserQuestion tool frequently hangs / the permission stream closes before a response is received (observed 2026-07-12 during RTM prod-install scoping — "Tool permission stream closed before response received"). Max explicitly asked for text-only questions.

**How to apply:** When scope is ambiguous, write the options inline as a short numbered/lettered list in prose and let Max reply in chat. Do not call AskUserQuestion. Relates to [[feedback_codebox_scripts]] (Max's formatting preferences).
