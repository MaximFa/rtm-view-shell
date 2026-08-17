---
name: ds-b-rolls
description: >-
  Finds ready-to-use B-roll / stock video clips that will later be edited into
  advertising videos (Meta / TikTok / Instagram / YouTube ads). Use this skill
  whenever the user wants footage, B-roll, stock video, "קטעי וידאו", "בי רול",
  "פוטג'", clips for an ad, visuals for a video, or describes a scene they need on
  screen ("I need a clip of someone unboxing a product", "תמצא לי בי רול של ריצה
  בחוף", "footage of pouring coffee", "צריך וידאו של אישה מורחת קרם"). It searches
  across multiple free stock-video sources, defaults to vertical phone format
  (9:16) for ads, presents the candidate clips with preview links FIRST for the
  user to approve, and only AFTER approval downloads and saves them to files with
  the names the user dictates. Trigger it even when the user doesn't say the words
  "B-roll" or "stock" — any request to find existing video footage for an ad,
  reel, or short qualifies.
---

# DS-B-ROLLS — B-roll finder for ad videos

You help the user assemble raw footage (B-roll) that they will later cut into
advertising videos. Your job is to understand exactly what should be *on screen*,
go find matching clips across free stock-video sources, show them to the user as
links/previews for approval, and only then download and save the approved ones
under the filenames the user chooses.

Conversation language follows the user (Hebrew by default for this user). File
names are always written in clean English/ASCII so they behave well on any system.

## The golden rule: approve before you save

Never download or save a clip before the user has seen it and approved it. The
workflow is always **search → present links → wait for approval → save with the
chosen name**. The user reviews previews in chat, picks the ones they want, and
tells you what to name each file. This keeps their folder clean and avoids
wasting downloads on clips that don't fit.

## Step 1 — Pin down the visual brief

Before searching, make sure you know what the clip must show. If the user's
request already answers these, don't re-ask — just confirm briefly and move on.
Otherwise ask only for what's missing (keep it to one short round of questions):

- **Subject / action**: what literally happens on screen (e.g. "a woman applying
  face cream and smiling", "close-up of sneakers running on a beach").
- **Mood / style**: bright & clean, cinematic, UGC/handheld, luxury, energetic, etc.
- **Quantity**: how many options to bring back per idea (default: 5–8 candidates).
- **Format**: default to **vertical 9:16 (phone / Reels / TikTok / Stories)** because
  that's what ad creatives almost always need. Only use 16:9 (landscape) or 1:1
  (square) if the user asks for it. Note: "phone format" = vertical = 9:16, not 16:9.
- **Duration**: if they care (e.g. "short 3–6s shots"). Otherwise no filter.

Translate the brief into 2–4 concrete English search queries — stock sites are
indexed in English, so a Hebrew request like "אישה מורחת קרם פנים" becomes queries
like `woman applying face cream`, `skincare routine closeup`, `face cream
application`. Searching a few phrasings gives much better coverage than one.

## Step 2 — Search across sources

Use the bundled search script, which queries multiple free stock-video sources at
once and returns normalized results (source, description, duration, resolution,
orientation, a preview thumbnail/page link, and a direct download URL):

```bash
python3 scripts/search_broll.py \
  --query "woman applying face cream" \
  --query "skincare routine closeup" \
  --orientation portrait \
  --per-source 6 \
  --out /path/to/outputs/broll_candidates.json
```

Sources and keys: the script uses the **Pexels** and **Pixabay** video APIs (both
free, both license footage for commercial/ad use). They each need a free API key.
The script reads keys from `PEXELS_API_KEY` and `PIXABAY_API_KEY` environment
variables. Read `references/sources.md` for how to get a key (takes ~1 minute) and
for the licensing notes you should pass on to the user.

If **no keys are available**, don't get stuck:
- Tell the user you can pull live downloadable results the moment they drop in a
  free Pexels/Pixabay key (point them to `references/sources.md`), and
- Meanwhile fall back to `WebSearch` to surface specific clip pages on Pexels,
  Pixabay, Coverr, Mixkit, and Videvo that match the brief, and present those
  page links for the user to eyeball. (You can't auto-download from a web-search
  fallback, but the user can confirm which ones they like and you save those.)

Filter the results to the requested orientation before presenting. For 9:16,
keep clips where height > width.

## Step 3 — Present candidates for approval

Show the candidates as a clean, numbered list grouped by the search idea. For each
clip give the user enough to judge it without leaving the chat:

```
🎬 Face cream — vertical clips

1. Woman applying moisturizer, bright bathroom · 9:16 · 12s · 1080×1920 · Pexels
   Preview: <preview/thumbnail link>     Page: <source page link>
2. Close-up cream on fingertip · 9:16 · 7s · 1080×1920 · Pixabay
   Preview: <preview link>     Page: <source page link>
...
```

Then ask which numbers they want and what to name each one. Don't save anything
yet. If nothing fits, refine the queries and search again rather than forcing a
weak clip.

## Step 4 — Save approved clips with the chosen names

Once the user approves specific clips and gives names, download each with the save
script. It sanitizes the name to ASCII, enforces a `.mp4` extension, avoids
overwriting, and appends a row to an index file so the user has a manifest of what
each file shows and where it came from:

```bash
python3 scripts/save_broll.py \
  --candidates /path/to/outputs/broll_candidates.json \
  --pick 1 --name "cream_apply_hero" \
  --pick 2 --name "cream_closeup_drop" \
  --dest /path/to/outputs/broll
```

`--pick N` refers to the candidate's number from `broll_candidates.json`; pair each
`--pick` with the `--name` the user gave. Saving by index keeps the exact
download URL, license, and source the search found.

After saving, confirm what landed where (file names + folder) and surface the
clips with the `present_files` tool so the user can open them. Mention the
`broll_index.csv` manifest in the destination folder.

## Naming conventions

Make file names safe and useful even when the user speaks Hebrew: lowercase
ASCII, words joined by underscores, no spaces or punctuation, `.mp4` extension. If
the user dictates a Hebrew name, transliterate it to readable English rather than
dropping it. If they don't give a name, propose one from the clip's description
(e.g. `woman_running_beach_01.mp4`) and confirm.

## Keep in mind

- These are advertising assets: favor clean, well-lit, modern-looking footage and
  steer away from clips with visible watermarks, on-screen text, or dated styling
  unless the brief asks for them.
- Always pass on the license note from `references/sources.md` so the user knows
  the clips are cleared for commercial/ad use and whether attribution is needed.
- It's fine to bring back a couple of "wildcard" options that interpret the brief
  loosely — sometimes an unexpected angle edits better than the literal one.
