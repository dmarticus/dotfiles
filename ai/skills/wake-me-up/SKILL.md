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
# If channels.yml has project_board: "<org>/<number>", pass it through:
~/.claude/skills/wake-me-up/scripts/github-attention.sh --since "$SINCE" --project-board "$PROJECT_BOARD"
```

Output JSON has four arrays:
- `review_requested` — each PR includes `review_decision`
- `my_open_prs` — each PR includes `checks_state`
- `mentions`
- `project_items` — open issues/PRs assigned to the user from the configured project board (excludes Done/Cancelled), each with `status` (e.g. "In Progress", "Todo")

**Filter `review_requested` before surfacing.** Only show PRs where `review_decision == "REVIEW_REQUIRED"` (or null/missing — same meaning). Drop PRs with `review_decision` of `APPROVED` or `CHANGES_REQUESTED` — those already have substantive feedback from someone else and don't need the user's input to ship.

**Highlight `my_open_prs` created since `$SINCE`** with `🆕` — those are the day's new work that the user might want to track. Group the multi-SDK `evaluate_flags` train (or any similar multi-repo effort) onto a single line if they share a title pattern; don't list 9 separate bullets for what's logically one effort.

### Step 4: Zendesk

```bash
~/.claude/skills/wake-me-up/scripts/zendesk-flags.sh --since "$SINCE"
```

Output is JSON with: `new_tickets`, `customer_replied` (tickets where the most recent comment is from the customer), `aging` (tickets open >7 days with no internal reply).

**Surface only tickets that are escalated or stuck — not routine `pending`.** Specifically:
- Tickets with `priority` of `urgent` or `high`.
- Tickets explicitly tagged as escalated (e.g. `escalated`, `vip`, `breaking`) or whose subject describes a customer-stated breaking issue.
- Tickets in `customer_replied` (the ball is in our court).
- Tickets in `aging` (open >7d) where the customer is the most recent commenter.

Do NOT include tickets in `pending` status by default — those are with someone else and the user doesn't need to be paged on them. Same for the wave of auto-filed `Bug Report: …` tickets in `new` status; treat them as a count-only summary unless one is flagged urgent.

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

### Step 6: Apply relevance rules

If `~/dev/ai/notes/wake-me-up/relevance.yml` exists, read it and apply its rules to filter and tier the items collected so far. The file uses **natural-language rules** under `keep` / `demote` / `hide` keys for each item type (`prs`, `zendesk`, `slack`). It also has a top-level `philosophy:` block that frames the overall standard.

Apply rules with judgment, not regex. For each item gathered in Steps 3–5, ask: which rule does this fit best? When in doubt, follow the philosophy's guidance — typically "lean toward demote over keep, and hide over demote."

Outcomes:
- **hide**: drop the item entirely. Don't include it in the local file or the Slack post.
- **demote**: include in the local file under "Below the fold", but exclude from the morning Slack post.
- **keep**: full visibility — include in both the local file and the Slack post.

The whole point: the morning Slack post should be a curated action list, not a comprehensive activity index. The user scans Slack/GitHub directly for general context.

If `relevance.yml` doesn't exist, skip this step (no filtering beyond defaults from earlier steps).

### Step 7: PostHog

Stub for now. Output: `PostHog: no signals configured yet.`

When ready, this step will fetch firing alerts, dashboards trending the wrong way, and saved insights with anomalies.

### Step 8: Categorize and write report

Write to `$OUT_FILE` using this structure. Omit empty sections rather than showing them as empty.

```markdown
# Start of day — {YYYY-MM-DD}

> Briefing covers activity since {since timestamp, human readable}

## 💬 Slack
{Actionable items only — direct asks, customer-call requests, prod incident pings, manager DMs. Hyperlink the source thread/message permalink. Skip channels and per-channel summaries unless an item demands action.}
- {Ping summary} — [thread](permalink)

## 🔍 Review requests
{PRs needing the user's input (filtered by `review_decision == REVIEW_REQUIRED` and `relevance.yml`). Group by author tier — teammates first, then others. PRs >24h get 🔥. End the section with a link to the GitHub review queue.}

### From teammates
- 🔥 [#1234 Title](url) — @teammate, 2d

### From everyone else
- 🔥 [#9876 Title](url) — @rando, 12d

[all review-requested →](https://github.com/pulls?q=is%3Aopen+is%3Apr+review-requested%3A%40me)

## 🚀 Your work
{Issues from the project board (in_progress + todos) + your open PRs.}

### In progress (from project board)
- [#NNNN](url) — title

### Todo (from project board)
- [#NNNN](url) — title (omit section if none)

### Open PRs (N)
- 🆕 [#NNNN](url) — title (created since SINCE)
- [#NNNN](url) — title
- multi-repo train: collapse logically-grouped PRs onto one line

[all my PRs →](https://github.com/pulls?q=is%3Aopen+is%3Apr+author%3A<USERNAME>+archived%3Afalse)

## 🎫 Ops
{Escalated Zendesk tickets only. Omit this section entirely if there are zero. Don't show "0 escalated" — just leave it out.}
- [Ticket #NNNN](url) — title

## 📋 Carry-over from yesterday
{Unchecked items from previous wake-me-up file, after auto-skip pass (Step 2).}
- [ ] Finish migration plan for X
- [ ] Reply to gustavo's thread
```

The briefing is for *informing*, not *prescribing*. Don't add a "Today's plan" section or propose tasks the user didn't ask for — surface what changed, what's open, and what's stale, and let the user decide what to do with it.

### Step 9: Optional Slack post (when `morning_post_to:` is set)

If `channels.yml` has a `morning_post_to:` field (e.g. `#dylanthropy` for a personal channel), publish a condensed Slack-flavored version of the briefing there. Skip this step silently if the field is missing or the Slack MCP isn't connected.

Compose a short post — not the whole markdown file. Slack mrkdwn won't render headers cleanly, and the file path is useless from a phone. Aim for 8–15 lines total:

- Lead with `**Start of day — {date}**`. Just the date — no parentheticals, disclaimers, or "(re-render with X applied)" suffixes. The post should look the same every time at a glance.
- Section order: Slack → Review requests → Your work → Ops (omit if empty).
- **Spacing**: Slack collapses whitespace, but it does respect blank lines between paragraphs. Insert a blank line between every section AND between a section header and its content. Slack still squeezes things tight, but blank lines give the eye somewhere to rest. Don't run a section header directly into the previous list.
- **Hyperlink the source artifact** (Slack thread permalink, ticket URL, GitHub issue) so everything is tappable on mobile — never just the channel name. For Slack-originated items, link the message permalink, not the channel.
- Review queue: list **all** PRs that pass the "needs my input" filter (Step 3), grouped by tier (teammates first, then others), one terse line each — `🔥 [#NNNN](url) @author — short description`. Don't truncate with "…and N more". End the section with a link to the GitHub review queue.

Don't include a "Today's plan" or proposed-action section. Don't include the local file path either — it's useless on mobile and adds noise. Surface info, don't prescribe.

Concrete shape:

```
**Start of day — {date}**

💬 **Slack**

• {item}
• {item}

🔍 **Review requests** — N needing your input

**Teammates:**
• 🔥 [#X](url) @author — desc

**Others:**
• 🔥 [#Y](url) @author — desc

[all review-requested →](url)

🚀 **Your work**

**In progress:**
• [#Z](url) — title

**Open PRs (N):**
• 🆕 [#W](url) — title (created today)
• {rest}

[all my PRs →](url)
```

Use `<url|text>` link syntax. No AI/LLM attribution. Post directly with `slack_send_message` — no confirmation prompt for the morning post (the user opted in via config).

If posting fails, surface the error but don't fail the whole skill — the local file is still the source of truth.

### Step 10: Show and open

Print the report path (and the Slack message link if Step 9 ran). If `$EDITOR` is set, prompt: "Open in $EDITOR?" — open if user confirms.

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

# Direct teammates — their PRs are sorted to the top of "Review requests".
# GitHub logins (case-sensitive).
teammates:
  - gustavohstrassburger
  - haacked

# GitHub project board to fetch your assigned issues from for "Your work".
# Format: "<org>/<project_number>". Omit to skip the project board fetch.
project_board: "PostHog/112"

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

If the file is missing, do step 5 against a default of `team-feature-flags` only, skip the watchlist and step 9, and tell the user to create the file.
