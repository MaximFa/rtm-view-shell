# B-roll sources, API keys & licensing

The `search_broll.py` script pulls real, downloadable clips from two free
stock-video APIs. Both license their footage for commercial use (including paid
ads). Get the free keys once and the skill works end-to-end.

## Pexels (videos)
- Sign up free: https://www.pexels.com/api/
- After signing in, the dashboard shows your API key instantly.
- Set it for the session: `export PEXELS_API_KEY="your_key_here"`
- License: **Pexels License** — free for commercial and personal use, no
  attribution required. You may not sell unaltered copies or imply endorsement.

## Pixabay (videos)
- Sign up free: https://pixabay.com/api/docs/
- Your key appears in the docs page once logged in.
- Set it for the session: `export PIXABAY_API_KEY="your_key_here"`
- License: **Pixabay Content License** — free for commercial use, no attribution
  required. Don't redistribute the raw files as stock themselves.

## If you have no keys yet
The skill still helps: it falls back to `WebSearch` to surface specific clip
pages on these sites so the user can review them by link. Auto-download only
works once a key is present, because the APIs are what expose direct file URLs.

Other good free libraries to surface via web search when needed:
- Coverr — https://coverr.co  (free, commercial use)
- Mixkit — https://mixkit.co/free-stock-video/  (free, Mixkit license)
- Videvo — https://www.videvo.net  (mixed; check per-clip license)

## What to tell the user about licensing
Always pass on a one-line note when you deliver clips, e.g.:
"These are from Pexels/Pixabay and are cleared for commercial/ad use with no
attribution required." If a clip ever comes from a source with stricter terms
(e.g. some Videvo clips), flag that explicitly.
