# Turbo Carlo — Domain Glossary

Shared vocabulary for the Decision Lab. These are domain terms in user/product language —
not implementation detail. Every later slice relies on this vocabulary.

- **Decision Lab** — the v1 feature: compare two financial futures for one decision.

- **Scenario** — a pre-built decision archetype (one of six). Has a title, a default amount
  and time horizon, a currency, and two **Paths**.

- **Path** — one side of a comparison: a named strategy applied to an **Asset** over the
  horizon. Path A is the "growth/active" side, Path B the "stable/conservative" side.

- **Asset** — a named investable thing (world index, S&P 500, NVDA, bonds, high-yield savings,
  60/40). Carries the drift and volatility derived from history; **the user never sees these
  numbers**.

- **Comparison** — one run of a Scenario at a chosen amount and horizon. It is immutable, and
  owns the result and a permalink.

- **Permalink / result** — the shareable `/r/:slug` page; the product's landing page for
  shared links. Anyone arriving from a shared link lands directly on a fully-rendered result.

- **Win rate** — the share of simulated futures in which Path A ends ahead of Path B.

- **Snapshot ("data as of")** — the historical parameters frozen into a Comparison at the
  moment it is created, so a shared link reproduces its original result even after the
  underlying data is later refreshed.

- **Coupled futures** — when both paths ride the *same* market (e.g. lump-sum vs spread,
  100%-stocks vs 60/40), they are simulated against the *same* random market path so the
  comparison is apples-to-apples.
