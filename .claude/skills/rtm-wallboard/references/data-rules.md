# Designing the dataset

The layout is the easy part. What makes one of these screens convincing — or
embarrassing — is whether the numbers survive a contact-center manager reading
them for thirty seconds. Design the dataset first, then lay it out.

## Reconciliation

Pick the headline volume, then derive everything from it rather than inventing
each figure independently.

- Per-queue totals sum to the headline total. Per-queue answered and abandoned sum
  to the headline answered and abandoned.
- Waiting-now across queues equals the "currently waiting" KPI tile.
- Agents connected per queue sums to the connected-agents figure and to the donut
  total.
- Bot screens: `bot intake = contained + escalated`, and `escalated` equals the
  sum of the queue volumes, because escalations are exactly what lands in the
  human queues. Voice-bot plus chatbot equals bot intake.
- Per-agent state seconds sum to that agent's total login time; the four
  percentages sum to 100.

Worked example — the banking demo this skill was built from:

```
bot intake           1,284
  contained in bot     731   (56.9%, target ≥ 50%)
  escalated            553   = WhatsApp 187 + web chat 142 + app 96
                             + email 61 + messenger 38 + voice-bot escal. 29
voice bot              902   (70.3%)   chatbot   382   (29.7%)   → 1,284 ✓
```

## Weighted averages

Never average the rows. A six-row table where one row has 29 conversations and
another has 187 gives a badly wrong headline if averaged flat.

```
ASA_total = Σ(ASA_q × volume_q) / Σ volume_q
SLA_total = Σ(SLA_q × volume_q) / Σ volume_q
abandon_total = Σ abandoned_q / Σ volume_q
```

Recompute these every tick rather than storing them, so the footer can never drift
away from the rows above it.

## The verdict mix

A screen that is entirely green demonstrates nothing; entirely red looks like a
stress test. Target roughly:

- most values green,
- one or two amber,
- exactly one red, and make it the narrative the whole screen supports.

Then wire the rest of the screen to that one problem: the failing queue row is red,
the ticker's first message names it, the WFM recommendation proposes the fix, and
the threshold panel's marker sits in the red band.

## Make the failure a distribution failure

The strongest demo is averages inside target while the tail breaches:

```
average wait  00:27  ✅ target ≤ 00:30
maximum wait  02:07  ❌ target ≤ 01:30
```

A daily report shows the first number and reports a good day. The wallboard shows
both and a supervisor acts. That contrast is the product argument, delivered by
the data rather than by a bullet point — so build it in deliberately.

## Paired screens

When producing more than one screen for the same deck, freeze a single moment —
same timestamp, same headcount, same volumes — and show different cuts of it.
Give each screen a *different* problem so the pair isn't repetitive:

| Screen | In order | The problem |
|---|---|---|
| Digital channels + bots | staffing has slack | one channel (email) misses the response SLA |
| Voice operations | queues are manageable | staffing gap of 6 against Erlang requirement |

A reviewer who compares the two and finds the volumes reconcile will trust both.

## Invented identities

- Names plausible for the market and the language; do not reuse the names from a
  real customer's screen you were shown.
- Phone numbers in the local format, in ranges that are obviously not live
  (Israel: `05X-XXX-XXXX`).
- Conversation and ticket IDs with a channel prefix: `WA-48231`, `CH-77104`,
  `EM-30914`.
- Queue and channel names in the customer's own vocabulary for that vertical —
  banking gets mortgages, cards, fraud; telecom gets billing, roaming, faults.

## Time model

Set a specific date and time and keep it consistent across screens. Mid-morning
peak (≈11:40) is the most useful moment: the day has accumulated enough volume for
the cumulative counters to look real, and the queues are busy enough to justify
alerts.

Elapsed totals must agree with the clock: an agent logged in since 08:00 on an
11:42 screen has ~03:40:00 total login, and their talk + break + wrap + idle must
add up to that.

## Disclose the synthetics

Put one quiet line in the footer stating the data is a synthetic demonstration.
It costs nothing, it prevents a screenshot being mistaken for a customer's real
numbers, and it is the kind of detail that makes a reviewer trust the rest.
