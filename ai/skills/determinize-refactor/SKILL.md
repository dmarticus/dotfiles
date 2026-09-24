---
name: determinize-refactor
description: Analyze a prompt-heavy skill or agent and produce a prioritized migration plan that moves deterministic instructions out of prose into scripts or structured contracts — improving reliability and cutting token cost. Use when the user says "reduce prompt tokens", "make this skill deterministic", "script-mode this skill", or "audit a skill for token bloat". Outputs a Markdown audit report with a token summary and per-file conversion plan, NOT code.
argument-hint: "<skill-or-agent path>"
---

<!-- Adapted from jasonv-skills/meta/determinize-refactor (MIT, Jason Varbedian) -->

# Determinism refactor (script-mode)

Analyze a prompt-heavy skill and produce a migration plan that improves reliability and
reduces token cost by moving the **deterministic** parts of the prose into scripts or
structured contracts, leaving only genuine judgment in the prompt.

The target style already exists in this collection: `ci-monitor`, `sprint-planning`, and
`resolve-conflicts` keep deterministic steps in `scripts/` and reserve the SKILL.md for
judgment. Prose-heavy skills should converge toward that shape when it pays.

## Inputs

Accept any of:

- a skill path (e.g. `~/.dotfiles/ai/skills/<skill-name>/`)
- an agent file (e.g. `~/.dotfiles/ai/agents/<agent>.md`)
- a single prompt file (`SKILL.md` or `references/*.md`)

If no path is provided, ask for the target scope before continuing.

## Workflow

### 1. Collect the prompt corpus

Gather `SKILL.md` + all `references/*.md` and `templates/*.md` for each target. Include other
markdown only when it directly affects runtime behavior. Ignore tests/scripts for token
sizing, but read them to check whether logic is *already* deterministic.

### 2. Classify by determinism

Tag each section as one of: **strict workflow**, **fixed mappings**, **arg/call contracts**,
**output templates**, **retry/error policy**, **partial (mixed rules + judgment)**, **narrative
/ human explanation**, **context**, or **interpretation guidance**. Attach an evidence snippet
from the exact file/section for every tag.

### 3. Quantify token cost (state assumptions)

Default line-based estimate: `tokens ≈ non_empty_lines × 11` — show a low/high range with
multipliers **9 and 13**. Break the count down **by file**, **by section**, and **by execution
path** (fast path vs full path) when the skill has conditional flows.

### 4. Estimate refactor savings

Apply reducibility by classification:

| Class | Reducible |
|---|---|
| Deterministic (strict workflow, fixed mappings, contracts, templates) | 80–95% |
| Partial (mixed rules + judgment) | 30–60% |
| Narrative / interpretation | 10–20% |

Return **conservative** and **aggressive** totals, and highlight the **top 5 sections by
absolute token savings**.

### 5. Recommend prompt → script extractions

For each high-impact deterministic section, propose a target artifact:

- workflow state machine
- mapping / classification module
- scoring calculator
- output renderer
- validation-gate checker

Include the expected reliability benefit and the dependency risk. Follow local conventions:
shell scripts under the skill's `scripts/` dir, plain `echo` logging, and an entry in the
skill's `allowed-tools` frontmatter when it needs one.

### 6. Build the file-by-file conversion plan

For each convertible file: **what** (exact sections/rules to extract), **why** (determinism /
reliability / token rationale), **how** (script/module shape, inputs/outputs, integration
path). Plus metadata: suggested script path, estimated savings (conservative/aggressive),
priority (P0/P1/P2), risk (low/med/high), dependencies/blockers.

## Output structure (Markdown report per path)

1. **Token summary** (mandatory, first section)
   - original tokens (one clear number + optional low/high range)
   - post-refactor: conservative and aggressive
   - % improvement, conservative and aggressive
   - show the formulas explicitly:
     - `post_refactor_tokens = original_tokens − reducible_tokens`
     - `improvement_percent = (reducible_tokens / original_tokens) × 100`
2. **Concrete savings breakdown** (conservative + aggressive)
3. **Top deterministic sections to extract** first
4. **Detailed file conversion plan** — a per-file table: `file | what | why | how | script path | savings (cons/agg) | priority | risk`
5. **Suggested pipeline changes**
6. **Residual prompt** — what should stay model-driven (the judgment that *shouldn't* be scripted)

If multiple paths are given, separate reports with clear `## <path>` headings.

## Quality bar

- Every quantified claim includes its formula and assumptions.
- Every extraction recommendation cites source files.
- Token counts are estimates unless a real tokenizer was run — say which.
- Call out known uncertainty explicitly.
- Never omit original tokens, post-refactor tokens, or % improvement.
- Never omit the conservative/aggressive what/why/how conversion list.
- Default output is a Markdown audit report per path. **Never** emit JSON/code files unless the user explicitly asks.

## Errors

| Issue | Fix |
|---|---|
| No path given | Ask for the target skill/agent/file before analyzing. |
| Skill is already lean (mostly judgment) | Report low reducibility honestly; recommend leaving it as prose. |
| Can't measure real tokens | Use the line-based estimate and label it an estimate with the multiplier range. |
| User wants the code, not a plan | This skill outputs the plan; hand off to an implementer to write the scripts. |
| Target path unreadable (permissions/sandbox) | Report which paths were skipped; never guess their contents. |
