# Project instructions — "RTM View Shell"

> **⚠ PROVENANCE — READ BEFORE TRUSTING THIS FILE.**
> This is NOT a byte-faithful export. The project-instruction text is an account-side settings field with no
> on-disk copy; it reaches a session only through the system prompt, HTML-escaped in transit
> (`&quot;` for `"`, `&amp;` for `&`). What follows is that text with the entities decoded back.
> Original typos are PRESERVED deliberately ("контакного", "Blazure", "Размешение", "тз") — this is an
> export, not an edit, and preserving them is what makes a character-level comparison possible.
>
> **Before the migration: open the project settings on the originating account, compare against the block
> below, and correct this file if anything differs.** Then paste it verbatim into the new account.
>
> Captured 2026-08-17 by curator-0611. Status: UNVERIFIED against the settings field.

---

Before writing any status document, sprint report, or "delivered" claim — verify each asserted file via ls / git log / Read. Tool success ≠ delivery. See CLAUDE.md §0.
Мы будем писать техническое задание для графической оболочки системы отображения данных реального времени контакного центра. Оболочка будет позволять создавать экраны (дэшборды) на основе Blazure. Задачей оболочки является создание и управление пользователями, система управления разрешениями пользователей на основе Permission Groups, логинирование пользователей с учетом всех требований ИБ (JWT, SSO, 2FA с мэйлом, аудит подключений), управление разрешениями Permission Groups (меню, экраны (view, edit, delete), Queues, Skills, Agent Supergroups, Business Units). Сами компоненты визуализации данных в оболочку не включены, она будет только позволять выбрать категорию и виджет из списка. Размешение drag&drop и конфигурация виджетов на экране в данное тз не включено. Язык - .NET (C#). Должны быть соблюдены все требования по написанию безопасного кода, если нужно, указывать детально. Диалог ведем на русском, документацию ведем на английском

---

## Notes for the new account

- The first paragraph is the **verification-discipline directive** and is load-bearing: it is the same rule
  as `CLAUDE.md §0` and the reason every "delivered" claim in this project is checked against the object
  store. Do not drop it when re-pasting.
- The last sentence sets the standing language split: **conversation in Russian, documentation in English.**
- Agent Desktop is NOT covered by these instructions and stays on the originating account.
