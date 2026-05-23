# ADR-0001: Common random numbers for same-underlying scenarios

- **Status:** Accepted
- **Date:** 2026-05-23

## Context

The Decision Lab compares two **Paths** by Monte Carlo and reports a **win rate** — the share
of simulated futures in which Path A ends ahead of Path B. Some scenarios pit two strategies
against the *same* underlying market: lump-sum vs dollar-cost averaging (both ride the S&P);
the future 100%-stocks vs 60/40 (a shared equity factor). For these, the only honest
difference between the two sides is the *strategy* — not the market they happen to draw.

If each side draws its own independent random market, the two paths within a single simulation
experience *different* markets, so the win rate measures noise rather than the strategy gap.
Empirically, independent draws give lump-vs-DCA a win rate hovering around 50% (a coin flip),
which would make the headline ("lump sum wins in N% of futures") meaningless and the DCA
insight untrue.

## Decision

When a scenario's two paths share an underlying, drive **both** sides off the **same
per-simulation Z-sequence** (one shared market path per simulation `i`, independent across
simulations). When the two assets genuinely differ (stocks vs HYSA, invest vs debt payoff),
keep independent draws.

This is declared per scenario via a `coupled_randomness` boolean on `Scenario`, threaded into
`Monte::Simulator` (`coupled:`). In `Simulator#call`, a coupled run draws one `normals` array
per simulation and feeds the same array to both `Monte::Path.build` calls; an uncoupled run
draws independently per side (the original behavior, byte-for-byte unchanged). A deterministic
(σ=0) spec ignores the supplied normals, so coupling a deterministic side is harmless.

`coupled_randomness` is **structural** per scenario — like a Path's `behavior` — so it does
**not** enter a Comparison's `dedup_key`. The scenario slug is already part of the key, and the
flag never varies for a given scenario.

## Consequences

- **Win rate becomes a real signal.** For lump-vs-DCA at S&P parameters the coupled win rate
  is a decisive, repeatable ~65% (lump usually beats DCA on a shared rising market), versus
  ~50% noise under independent draws.
- **The simulator threads a shared per-simulation normals array** for coupled scenarios; the
  per-path `normals` seam in `Monte::Path` (established when path behaviors landed) is what
  makes this a Simulator-only change.
- **Coupled results differ from the prototype's independent-draw charts.** This is intended —
  the prototype's arithmetic was throwaway.
- **Uncoupled scenarios are unaffected**, so existing frozen permalinks (e.g. invest-vs-savings)
  reproduce exactly.
