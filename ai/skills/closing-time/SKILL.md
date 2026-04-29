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

Read `$BRIEFING` and extract:
- Items that were marked urgent (Blockers section).
- PRs in flight (yours).
- Today's plan checklist — note which items are checked off (`- [x]`) vs still open (`- [ ]`).
- Any free-form notes the user appended during the day.

### Step 3: Collect what shipped

Ask the user, in one prompt:

> "What did you ship, resolve, or move forward today? Dump it freely — bullets, half-sentences, PR numbers, ticket numbers, whatever. I'll shape it."

Wait for their response. Do not draft yet.

If they reply "use the briefing" or similar, infer from checked-off plan items and PR status changes since the morning. Otherwise, use what they said as the source of truth and treat the briefing as background context only.

### Step 4: Draft the Slack post

Compose a short Slack-flavored update. Conventions:

- Lead with the most concrete shipped/landed thing.
- One bullet per item. Link PRs and tickets inline using Slack link syntax: `<url|text>`.
- Keep it terse — aim for 5–8 bullets, not a novel.
- Match Dylan's voice from the briefing: lowercase-friendly, direct, no marketing language. No "I'm excited to share that…" preambles.
- Never include AI/LLM attribution or co-authorship. Write as Dylan.
- If a blocker from the morning is still open, mention it explicitly under a `still open:` line so it carries to tomorrow.

Example shape (illustrative, not a template to copy literally):

```
EOD wrap:
• shipped <url|posthog-python#539> — single-call evaluate_flags()
• <url|#56822> error boundary fix is in review
• picked up <url|ticket #57101> latency report — initial triage shows X
still open:
• phil's encrypted-payload regression on remote config flags — picking up tomorrow
```

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
