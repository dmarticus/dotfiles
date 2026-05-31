# Tufte Core Principles

Core principles from Edward Tufte's *The Visual Display of Quantitative Information* (1983, 2nd ed. 2001). This is the base the other reference files extend.

> Graphical excellence is that which gives to the viewer the greatest number of ideas in the shortest time with the least ink in the smallest space.

---

## 1. Graphical Integrity

A graphic must not distort the underlying data. The visual representation of numbers should be directly proportional to the numbers themselves.

**The Lie Factor:**

```text
              size of effect shown in graphic
Lie Factor = ─────────────────────────────────
              size of effect in the data
```

- A truthful graphic has a Lie Factor between **0.95 and 1.05**.
- Above ~1.05: the graphic exaggerates. Below ~0.95: it understates.

**Integrity rules:**

- Use a consistent, clearly labeled scale.
- For bar charts, start the value axis at **zero** — a truncated baseline inflates apparent differences.
- Vary data dimensions, not design dimensions. If a quantity doubles, don't scale both width *and* height of an icon (area grows 4×, volume 8×) — that's the classic area/volume lie.
- Show data in context; don't crop out the comparison that gives a number meaning.
- The number of information-carrying dimensions in the graphic should not exceed the number of dimensions in the data.

---

## 2. Data-Ink Ratio

Most of a graphic's ink should present data. Non-data ink and redundant data-ink are candidates for deletion.

```text
                  data-ink           ink that, if erased, would
Data-Ink Ratio = ───────────  =  the loss of data information
                  total ink
```

**Maximize it by:**

- Erasing non-data ink — within reason.
- Erasing redundant data-ink — within reason.
- Editing and revising.

**Two governing rules:**

1. **Above all else, show the data.**
2. **Maximize the data-ink ratio**, within reason.

Practical moves: drop the chart border, drop heavy gridlines (or make them faint/white), remove tick marks the data already implies, label directly instead of with a separate legend.

---

## 3. Chartjunk

Decoration that carries no information and often actively interferes with it.

**Forms of chartjunk:**

- **Moiré vibration** — patterned fills (hatching, cross-hatching) that shimmer and distract.
- **The grid** — heavy gridlines that compete with the data. Mute them or remove them.
- **The duck** — a graphic so dominated by decoration that the design *becomes* the content (named for a duck-shaped building). Ornament masquerading as data.

Forbidding chartjunk is a low bar; clearing it is the start, not the goal.

---

## 4. Data Density and Small Multiples

**Data density** = number of entries in the data matrix ÷ area of the graphic. Most statistical graphics can be shrunk well below their usual size and still read clearly; small, dense graphics respect the viewer.

**Small multiples:** repeated frames of the same design structure, varying one variable (usually time, place, or a category). The constant design lets the eye compare changes in the data rather than re-learning a new layout each time.

- Use when the comparison is the point — across time, region, treatment, or scenario.
- Keep scales, axes, and encodings identical across panels.
- Index them so a reader can locate any single frame, then scan the whole field.

---

## 5. Multifunctioning Graphical Elements

Make each mark do more than one job. A single element can simultaneously record data, show a distribution, and frame the plot.

- **Range-frame:** axis lines that span only the actual data range (see `analytical-design.md`).
- **Dot-dash plot:** axes that double as marginal distributions.
- Direct labels that are also the data points.

---

## 6. Avoid Common Distortions

- **Pie charts:** weak — the eye judges angles and areas poorly. Prefer a bar chart or a small table; a table often beats a pie outright.
- **3D effects on 2D data:** depth, perspective, and shadows distort proportion and add no information.
- **Dual y-axes:** invite spurious correlation; the crossover point is an artifact of arbitrary scaling.

---

## 7. Friendly Data Graphics

Make the graphic legible to a stranger:

- Words spelled out, not abbreviated or coded.
- Direct labeling — no legend hunting, no decoder ring.
- Type set horizontally; an elaborate encoding shouldn't require the reader to learn it.

---

## The Tufte Test (7 questions)

Apply to any visualization. Continue with questions 8–14 in `analytical-design.md`.

1. **Integrity:** Is the Lie Factor ≈ 1.0? Are baselines and scales honest?
2. **Data-ink:** Is non-data ink minimized? What could be erased without losing information?
3. **Chartjunk:** Is there moiré, heavy grid, or "duck" decoration to remove?
4. **Density:** Is the data density appropriate — neither starved nor needlessly large?
5. **Small multiples:** Would repeated, constant-design frames make the comparison clearer?
6. **Multifunctioning ink:** Could any element carry more information (range-frame, direct labels)?
7. **Friendliness:** Is everything directly and legibly labeled, readable without a key?
