---
name: genesys-migration
description: Migrating an IceLib-based .NET app to the Genesys Cloud CX Platform API
sources: [backfill]
aliases: [Genesys Cloud CX, IceLib migration, PureConnect migration]
---
- [stated] Translating an IceLib-based (.NET SDK, PureConnect/CIC) application to the Genesys Cloud CX Platform API
- [stated] Core paradigm shift: from stateful IceLib sessions to REST + WebSocket
- [stated] Uses OAuth2 authentication
- [stated] Object model mapping: Interaction → Conversation/participant PATCH; presence/routing status APIs
- [stated] Event system migration: from IceLib's Watch/subscription model to Genesys Cloud notification topics
- [stated] Has solid existing familiarity with contact center development concepts