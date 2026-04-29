---
name: tune
description: >
  Walk through items from the most recent wake-me-up briefing one-by-one and
  collect keep/demote/hide labels from the user. After the round, generalize
  the labels into natural-language rules and append them to
  ~/dev/ai/notes/wake-me-up/relevance.yml for confirmation. Use when the user
  says "/tune", "tune the briefing", "improve relevance", or wants to teach
  the morning briefing what's signal vs. noise.
argument-hint: "[--briefing <YYYY-MM-DD>] [prs|zendesk|slack]"
model: sonnet
---

# Tune

Train the relevance filter for `wake-me-up` by labeling individual items from a recent briefing. Rules persist to `~/dev/ai/notes/wake-me-up/relevance.yml` and are consulted by wake-me-up Step 6.

## Purpose

Rules learned in the abstract drift fast. Rules learned from real items the user just saw stick. This skill is the feedback loop.

## Steps

### Step 1: Pick a briefing

Default to the most recent file in `~/dev/ai/notes/wake-me-up/` (excluding today's if it's still in progress). Honor `--briefing YYYY-MM-DD` if passed.

If no briefing exists, tell the user to run `/wake-me-up` first.

### Step 2: Collect items to label

Parse the briefing into discrete items, scoped by the optional category arg (`prs`, `zendesk`, or `slack`). Without the arg, do all three in that order.

For each item, capture: identifier (PR #, ticket #, message permalink), author/source, age, one-line title.

### Step 3: One-by-one prompt

Present items one at a time, in this format:

```
N/TOTAL

[#1234](url) — @author, 5d, "Title goes here"
{one-sentence editorial color, e.g. "FF-titled but stale" or "Direct ask of you"}

keep / demote / hide?
```

Wait for the user's reply before moving on. Accept variations: `k` / `keep`, `d` / `demote`, `h` / `hide`, plus inline rationale ("hide, this should be pending").

If the user signals a batch ("hide both", "hide all from @harihran-del"), apply to subsequent matching items without re-asking.

### Step 4: Watch for emerging patterns

After each label, scan the running set of decisions for clusters. When you see ≥3 same-label items sharing a clear attribute (author, age band, repo, topic), surface the pattern early so the user can opt into a batch rule:

> "That's 3 hides in a row from @harihran-del. Want me to hide everything from this author going forward? (yes / keep going)"

Don't push too hard — the user said "1-by-1" for a reason. Only batch when the pattern is unambiguous.

### Step 5: Propose rules

After the round, group decisions and propose natural-language rules:

```
Proposed rules from this session:

# prs / hide
- "PRs older than 60 days, regardless of topic"
- "Anything authored by @harihran-del"

# prs / demote
- "AI / product-launch PRs not directly in Dylan's domain"

# zendesk / hide
- "Anything not explicitly escalated; status field is unreliable"
```

For each, ask: **accept / reword / drop**. Loop until the user is satisfied.

### Step 6: Write to relevance.yml

Append (or merge into) `~/dev/ai/notes/wake-me-up/relevance.yml` under the matching `prs` / `zendesk` / `slack` block and `keep` / `demote` / `hide` key.

Don't duplicate rules. If a new rule contradicts an existing one, ask the user which to keep.

Preserve the `philosophy:` block at the top of the file. If it doesn't exist yet, propose one based on observed labels:

> "Philosophy I'm inferring: '{summary}'. Save this as the top-level philosophy?"

### Step 7: Show diff

Print a diff of what was added to relevance.yml. The user should be able to see exactly what changed. End with: "Next /wake-me-up will use these rules."

## Guardrails

- **One item at a time** unless the user explicitly batches.
- **Rules in the user's voice.** Don't generalize beyond what the labels support.
- **Inspectable always.** Final write goes through Step 7's diff. No silent additions.
- **Don't relabel.** If the same PR shows up in two future briefings, the user can re-tune; don't try to remember per-item decisions across sessions, only the abstracted rules.
