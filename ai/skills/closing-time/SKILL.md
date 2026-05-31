---
name: closing-time
description: >
  End-of-day counterpart to wake-me-up. Reads today's morning briefing at
  ~/dev/ai/notes/wake-me-up/{date}.md, asks the user what they shipped or
  resolved, drafts a Slack wrap-up post in the user's voice, shows the draft
  for explicit confirmation, then posts it on the user's behalf via the Slack
  MCP. Appends the posted summary back to the briefing file so the file is a
  full day record. Use when the user says "/closing-time", "wrap the day",
  "end of day post", or wants help summarizing what they did.
argument-hint: "[--draft-only] [--channel <name>]"
model: sonnet
---

# Closing Time

Wrap the day: read the morning briefing, collect what actually got done, and post a wrap-up to Slack — but only after the user has approved the draft.

## Purpose

Compress a day's worth of work into a short, honest Slack update without forcing the user to write it from scratch. The user always sees the draft before anything is sent.

## Steps

### Step 1: Setup

```bash
TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/dev/ai/notes/wake-me-up/$TODAY.md"
CHANNELS_YML="$HOME/dev/ai/notes/wake-me-up/channels.yml"
```

If `$BRIEFING` doesn't exist, ask the user whether they want to proceed without one (e.g. they didn't run wake-me-up this morning) or run wake-me-up first. If they proceed without, skip Step 2 and rely entirely on the user's free-form input in Step 3.

### Step 2: Read the morning briefing

Read `$BRIEFING` and extract everything that was *on the user's radar this morning* — these become the day's effective TODO list, even though the briefing intentionally doesn't include a proposed-plan section. Pull items from these sections:

- `💬 Slack` — direct asks/pings (e.g. "Leonhard wants you on a call", "Patricio asks X")
- `🔍 Review requests` — PRs needing the user's input
- `🚀 Your work` → `In progress` — project-board issues the user was actively working
- `🚀 Your work` → `Open PRs` — especially anything marked 🆕 (created today)
- `📋 Carry-over from yesterday` — items the user hadn't gotten to
- `🎫 Ops` — escalated tickets (if present)

Hold the union of these as `morning_items`. Step 4 will report against them.

Also extract any free-form notes the user appended during the day (e.g. status updates added to the briefing file mid-day).

### Step 3: Collect what shipped

Ask the user, in one prompt:

> "What did you ship, resolve, or move forward today? Dump it freely — bullets, half-sentences, PR numbers, ticket numbers, whatever. I'll shape it."

Wait for their response. Do not draft yet.

If they reply "use the briefing" or similar, infer from checked-off plan items and PR status changes since the morning. Otherwise, use what they said as the source of truth and treat the briefing as background context only.

### Step 4: Draft the Slack post

Cross-reference what the user just told you against `morning_items`. Bucket each item into one of three states:

- **Done** — user explicitly mentioned shipping/resolving it, OR a referenced PR/issue is now merged/closed (verifiable via gh).
- **In flight** — user mentioned progress but didn't finish, or it's still open.
- **Untouched** — was on the morning radar but wasn't mentioned at all in the user's input.

Then draft the Slack post with this shape (parallel to wake-me-up's structure so it reads as a closing of the loop):

```text
**End of day — {date}**

✅ **Done**

• {item} {link}
• {item} {link}

─────

🟡 **In flight**

• {item} — {one-line status if the user gave one} {link}

─────

📋 **Carrying to tomorrow**

• {item that was on the radar but didn't get touched}

─────

🚀 **Bonus** _(only if non-empty — work shipped that wasn't on the morning list)_

• {item} {link}
```

Conventions:

- One bullet per item. Hyperlink the source artifact using Slack's link syntax `<url|text>` — same as the morning post.
- Keep each bullet terse; one line each. Aim for 8–12 bullets total across all sections.
- Match Dylan's voice from the morning briefing: lowercase-friendly, direct, no marketing language, no "I'm excited to share…" preambles.
- Never include AI/LLM attribution or co-authorship. Write as Dylan.
- Use the same `─────` separators between sections that the morning post uses.
- Omit any section that's empty (don't write `**Bonus**` followed by nothing).

If a `Done` item maps cleanly to a morning `Slack` ping or `Review requests` entry, mention that connection in the bullet (e.g. "replied to Leonhard re: Voy call → booked for Friday"). The point is to close the loop.

### Step 5: Confirm before posting

Show the draft inline. Ask the user:

> "Post this to **{destination}**? (yes / edit / cancel)"

- If they say **yes** (or any clear affirmative): proceed to Step 6.
- If they say **edit** or paste a revised version: incorporate and re-confirm. Loop until they approve or cancel.
- If they say **cancel** or anything ambiguous: stop. Do not post. Offer to save the draft locally instead.

If invoked with `--draft-only`, skip Step 6 entirely and just print the draft.

### Step 6: Post to Slack

Resolve the destination from `channels.yml`'s `wrap_up:` block (see Configuration), or from the `--channel <name>` arg if passed.

- Look up channel ID with `slack_search_channels` if you only have a name.
- Send with `slack_send_message`. Capture the returned message URL/ts.

If the post fails, surface the error and stop — do not retry blindly. The user can re-invoke after fixing.

### Step 7: Archive into the briefing

Append the posted content (verbatim) to `$BRIEFING` under a new section:

```markdown
## ✅ Closed out — {time posted, e.g. 17:42 PDT}
{the exact text that was posted}

Posted to {channel/user} — {message link}
```

This makes the morning briefing file a complete record of the day. If `$BRIEFING` doesn't exist, write the wrap-up to `$HOME/dev/ai/notes/wake-me-up/$TODAY.md` as a fresh file with just this section.

### Step 8: Final confirmation

Print: the message link, the destination, and the file path that was updated. One line each.

## Configuration

`~/dev/ai/notes/wake-me-up/channels.yml` extension:

```yaml
# Existing wake-me-up section:
channels:
  team-feature-flags: { weight: high, summarize_above: 1 }

# New closing-time section:
wrap_up:
  post_to: "team-feature-flags"   # channel name OR @username for DM
  # Optional: a different destination for half-day vs full-day posts.
  # Currently only post_to is used.
```

If `wrap_up.post_to` is missing and `--channel` wasn't passed, ask the user once where to post and offer to save the answer to `channels.yml` for next time.

## Guardrails

- **Always show the draft before sending.** No exceptions, even if the user says "just post it" up front — show the draft, get the explicit yes, then send.
- **Write as Dylan.** Never include AI/LLM attribution, co-authorship, or "Generated by …" lines.
- **One post per invocation.** If the user wants a follow-up, they re-invoke the skill.
- **Don't fabricate.** If the user's input is sparse, ask one clarifying question rather than inventing accomplishments. If a PR/ticket isn't referenced in the morning briefing or the user's input, don't include it.
