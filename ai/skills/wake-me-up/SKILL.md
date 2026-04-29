---
name: wake-me-up
description: >
  Build a categorized morning briefing pulling from GitHub (PRs awaiting your
  review, your open PRs, @-mentions), Zendesk (Feature Flags team tickets),
  Slack (team channels, DMs, mentions — when MCP is configured), and PostHog
  (stub). Writes a markdown report to ~/dev/ai/notes/wake-me-up/{date}.md and
  surfaces blockers, review requests, in-flight work, and overnight catch-up.
  Use when the user says "/wake-me-up", "what do I need to do today",
  "morning briefing", or wants to triage their inbox.
argument-hint: "[--since <ISO timestamp>]"
model: sonnet
---

# Wake Me Up

Build a categorized briefing that helps the user get up to speed fast after EU has been yapping all morning.

`since` = the `--since` value if provided, otherwise default to yesterday 17:00 local time, or last Friday 17:00 if today is Monday.

## Purpose

Cut through overnight noise and surface what actually matters today, organized by what action it needs.

## Steps

### Step 1: Setup

Compute three values: `SINCE` (ISO 8601 with timezone, used for the GitHub/Zendesk scripts), `SINCE_EPOCH` (Unix seconds, used as `oldest` for Slack reads), and `TODAY` (output file path). Always derive `SINCE_EPOCH` from `SINCE` rather than constructing it by hand — passing a hand-built epoch to Slack is the bug that returned year-old data on the first run.

```bash
TODAY=$(date +%Y-%m-%d)
OUT_DIR="$HOME/dev/ai/notes/wake-me-up"
OUT_FILE="$OUT_DIR/$TODAY.md"
mkdir -p "$OUT_DIR"

# SINCE: yesterday 17:00 local, or last Friday 17:00 if today is Monday. Pass the value to the user-supplied --since if provided.
# Default (macOS BSD date):
SINCE=$(date -v-1d -v17H -v0M -v0S "+%Y-%m-%dT%H:%M:%S%z")
# Always derive epoch from SINCE so year/timezone can't drift:
SINCE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$SINCE" "+%s")
```

### Step 2: Read carry-over from yesterday

Find the most recent file in `~/dev/ai/notes/wake-me-up/` (excluding today's). If found, read it and extract unchecked checklist items (`- [ ]`).

Then **filter out items that current state shows are resolved** — don't carry forward what's already done. Verify against the data gathered in Steps 3–6 (e.g., a "review #56521" item drops if #56521 is now merged/closed; a "create channels.yml" item drops if the file now exists; a "triage ticket #X" item drops if the ticket status moved). When in doubt, keep it.

The principle: the carry-over list should only include things still genuinely open. The user shouldn't have to look at items they already finished.

If no prior file exists, skip carry-over.

### Step 3: GitHub

```bash
~/.claude/skills/wake-me-up/scripts/github-attention.sh --since "$SINCE"
```

Output is JSON with three arrays: `review_requested`, `my_open_prs` (each PR includes `checks_state`), and `mentions`.

### Step 4: Zendesk

```bash
~/.claude/skills/wake-me-up/scripts/zendesk-flags.sh --since "$SINCE"
```

Output is JSON with: `new_tickets`, `customer_replied` (tickets where the most recent comment is from the customer), `aging` (tickets open >7 days with no internal reply).

If the script reports it's not configured, include a short note in the report ("Zendesk: not configured — see scripts/zendesk-flags.sh") and continue.

### Step 5: Slack (when MCP is configured)

If a Slack MCP is connected, do the following. Otherwise skip and note "Slack: MCP not configured" in the report.

For each of the user's monitored channels (read from `~/dev/ai/notes/wake-me-up/channels.yml` if present, otherwise prompt the user to populate it):

1. Fetch messages with `slack_read_channel`, passing `oldest: "$SINCE_EPOCH"` (the Unix-seconds value computed in Step 1, NOT a hand-constructed timestamp). Slack's API silently accepts wrong epochs, so a year drift returns plausible-looking but stale data.
2. If the channel weight is `low` and the message count is below `summarize_above`, mark "(quiet)" and move on.
3. Otherwise:
   - Summarize in 1–3 lines.
   - Flag explicitly if any message mentions the user, mentions a feature flags topic (`feature flag`, `FF`, `cohort`, `early access`, `flag eval`), or references one of the user's open PR numbers (from Step 3).

Then:
- List unread DMs (sender + first-line preview).
- List @-mentions in threads with link.

#### Watchlist (customer channels)

If `channels.yml` defines a `watchlist:` block, scan for messages in channels matching `channel_pattern` that mention any of the `topics`.

**Important — Slack search doesn't expand wildcards in `in:` filters.** `in:posthog-*` is treated literally and returns nothing. Use this pattern instead:

1. For each topic (e.g. `"feature flag"`), run `slack_search_public_and_private` with the topic as the query and `after: SINCE`. Don't include `in:` at all.
2. Filter the results by channel name in post-processing: keep only hits where the channel name matches `channel_pattern` (treat the pattern as a glob — `posthog-*` means "channel name starts with `posthog-`").
3. Dedupe across topics (a message containing both "feature flag" and "cohort" should appear once).

Slack search is case-insensitive, so `FF` also catches `ff`. Surface ONLY the hits — not a full channel summary. Format each hit as `#channel — {one-line preview} ({link})`.

The point: you don't have to maintain a list of customer channels (they come and go), but you still hear if a customer channel mentions your product area.

### Step 6: PostHog

Stub for now. Output: `PostHog: no signals configured yet.`

When ready, this step will fetch firing alerts, dashboards trending the wrong way, and saved insights with anomalies.

### Step 7: Categorize and write report

Write to `$OUT_FILE` using this structure. Omit empty sections rather than showing them as empty.

```markdown
# Start of day — {YYYY-MM-DD}

> Briefing covers activity since {since timestamp, human readable}

## 🚨 Blockers / Urgent
{Items requiring action today: customer-facing tickets, security, prod incident,
PRs blocking your work. Each item: 1 line + link.}

## 🔄 Awaiting your review
{PRs requested from you. Group by author tier — teammates first (from `teammates:` in channels.yml), then everyone else. Within each group, sort by age. PRs older than 24h get 🔥. If a tier has no PRs, omit its subheading.}

### From teammates
- 🔥 [#1234 Title](url) — by @teammate, 2d
- [#1235 Title](url) — by @teammate, 4h

### From everyone else
- 🔥 [#9876 Title](url) — by @rando, 12d
- [#9877 Title](url) — by @rando, 6h

## 🛠️ Your work in flight
{Your open PRs with status.}
- [#5678 Title](url) — CI: ✅ passing | 🔴 failing | 🟡 pending — {N new comments}

## 🎫 Zendesk (Feature Flags)
{New + customer-replied tickets. Aging tickets in a sub-bullet.}
- New: 3
- Customer replied: 1 — [Ticket #1234](url) — {1-line summary}
- Aging (>7d): 2

## 💬 Overnight catch-up
### Slack
{Per-channel summaries. Quiet channels collapsed.}
- **#team-feature-flags** (14 msgs): Ruby announced spec change at 09:23. Gus
  shipped the cohort eval fix. Question for you in thread {link}.
- **#general**: (quiet)
- **DMs**: 2 unread — gustavo (auth issue?), ruby (sprint planning)
- **@-mentions**: 1 — {link, context}

## 📋 Carry-over from yesterday
{Unchecked items from previous wake-me-up file.}
- [ ] Finish migration plan for X
- [ ] Reply to gustavo's thread

## 📝 Today's plan
{Empty checklist for the user to fill in. Include the most likely candidates
inferred from the above as suggestions, prefixed with `-`. Final commitment is
the user's call.}
- [ ] {suggested item 1}
- [ ] {suggested item 2}
- [ ]
```

### Step 8: Optional Slack post (when `morning_post_to:` is set)

If `channels.yml` has a `morning_post_to:` field (e.g. `#dylanthropy` for a personal channel), publish a condensed Slack-flavored version of the briefing there. Skip this step silently if the field is missing or the Slack MCP isn't connected.

Compose a short post — not the whole markdown file. Slack mrkdwn won't render headers cleanly, and the file path is useless from a phone. Aim for 8–15 lines total:

- Lead with `*Start of day — {date}*` (mrkdwn bold).
- Top 3 urgent / blocker items, one line each. Skip if none.
- Review queue: just the 🔥 PRs (>24h old). Cap at 5; if more, end with `…and N more`.
- Today's plan as a checklist (use `•` not `- [ ]` since Slack doesn't render markdown checkboxes).
- Final line: `full briefing: ~/dev/ai/notes/wake-me-up/{date}.md` (acts as a reminder that the local file has the full picture).

Use `<url|text>` link syntax. No AI/LLM attribution. Post directly with `slack_send_message` — no confirmation prompt for the morning post (the user opted in via config).

If posting fails, surface the error but don't fail the whole skill — the local file is still the source of truth.

### Step 9: Show and open

Print the report path (and the Slack message link if Step 8 ran). If `$EDITOR` is set, prompt: "Open in $EDITOR?" — open if user confirms.

## Categorization rules (judgment calls)

- **Urgent** = customer-facing security/prod issue, PR explicitly marked blocking, or @-mention from manager/PM.
- **Review requested >24h** = 🔥. Means a teammate is waiting.
- **DM from a known PM/manager** (e.g. @rubychilds for Feature Flags) = always surface, never collapse.
- **EU yapping in your channels** = signal if it mentions FF topics, your name, or your PR numbers; otherwise summary only.
- **Zendesk aging >7d** = surface but don't mark urgent unless customer-replied.

## Configuration

`~/dev/ai/notes/wake-me-up/channels.yml` (user-maintained) controls Slack monitoring and optional auto-posting.

`weight` is binary: `high` always surfaces (even with 0 messages — silence is signal in announcement-style channels), `low` collapses to `(quiet)` when message count is below `summarize_above`.

```yaml
channels:
  team-feature-flags:    { weight: high }
  team-flags-platform:   { weight: high }
  team-blitzscale:       { weight: high }
  tell-posthog-anything: { weight: high }
  ask-posthog-anything:  { weight: low, summarize_above: 5 }
  dev:                   { weight: low, summarize_above: 5 }
  dev-stamp-exchange:    { weight: low, summarize_above: 1 }
  team-code:             { weight: low, summarize_above: 3 }
  papercuts:             { weight: low, summarize_above: 1 }

# Direct teammates — their PRs are sorted to the top of "Awaiting your review".
# GitHub logins (case-sensitive).
teammates:
  - gustavohstrassburger
  - haacked

# Watchlist: scan for topic mentions, then filter by channel name pattern.
# Useful for ephemeral customer/engagement channels (#posthog-*) that come and go.
watchlist:
  channel_pattern: "posthog-*"
  topics: ["feature flag", "FF", "cohort", "early access", "flag eval"]

# Optional: auto-post a condensed briefing to a personal channel for mobile access.
morning_post_to: "#dylanthropy"

# Used by the closing-time skill for the EOD wrap-up post.
wrap_up:
  post_to: "#team-feature-flags"
```

If the file is missing, do step 5 against a default of `team-feature-flags` only, skip the watchlist and step 8, and tell the user to create the file.
