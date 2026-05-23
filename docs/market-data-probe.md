# Market-data probe findings (issue #8 — the Phase 3 gate)

Run: `bin/rails market_data:probe` against the live free-tier Alpha Vantage key
(`Rails.application.credentials.alpha_vantage_api_key`).

- **Date of run:** 2026-05-23 (UTC)
- **Endpoints probed:** `TIME_SERIES_MONTHLY_ADJUSTED` for VT, SPY, QQQ, NVDA, AGG; then
  `FEDERAL_FUNDS_RATE` (monthly).

## Rate limit — CONFIRMED

The free key is, verbatim from the throttle response:

> Please consider spreading out your free API requests more sparingly (1 request per second).
> … the free key rate limit (**25 requests per day**), raise the per-second burst limit …

- **Daily limit: 25 requests/day.**
- **Burst limit: ~1 request/second.**

The throttle signal arrives as a **200 response** with a top-level `"Information"` key (the
client raises `RateLimitError` on it). In this run the first **5** monthly-adjusted calls
succeeded and the **6th** (FFR) was rate-limited even at a 2 s throttle — i.e. the daily quota
had already been partly consumed before the run (the per-second burst was not the binding
constraint at 2 s spacing). The 25/day cap is the real planning constraint.

**Implication for #10:** the daily refresh touches only **5 sources** — SPY, VT, NVDA, AGG
(monthly-adjusted) + FEDERAL_FUNDS_RATE — comfortably inside 25/day with margin for one retry.
A throttle of ~1–2 s satisfies the burst limit; the plan's 12 s is safely conservative. Spread
the run so it never collides with ad-hoc/manual probes on the same key the same day.

## Response shape — `TIME_SERIES_MONTHLY_ADJUSTED`

```jsonc
{
  "Meta Data": { "2. Symbol": "SPY", ... },
  "Monthly Adjusted Time Series": {
    "2026-05-22": { "1. open": ..., "2. high": ..., "3. low": ...,
                    "4. close": ..., "5. adjusted close": "745.6400",
                    "6. volume": ..., "7. dividend amount": ... },
    ...
  }
}
```

The client uses **`"5. adjusted close"`** (dividend/split-adjusted) and the date key, dropping the
rest. Returns `[{ observed_on: Date, close: Float }, ...]` newest-first.

## Per-symbol coverage

| Symbol | Observations | Earliest    | Latest (adj close)   | History |
|--------|-------------:|-------------|----------------------|--------:|
| VT     | 215          | 2008-07-31  | 2026-05-22 (155.57)  | 17.8 y  |
| SPY    | 318          | 1999-12-31  | 2026-05-22 (745.64)  | 26.4 y  |
| QQQ    | 318          | 1999-12-31  | 2026-05-22 (717.54)  | 26.4 y  |
| NVDA   | 318          | 1999-12-31  | 2026-05-22 (215.33)  | 26.4 y  |
| AGG    | 272          | 2003-10-31  | 2026-05-22 (98.44)   | 22.6 y  |

All five clear the **≥60 observation** and **freshness < 60 days** validation gates by a wide
margin (latest = the prior trading day).

## `FEDERAL_FUNDS_RATE`

Not live-confirmed in this run — it was the call that hit the daily limit. Shape per Alpha
Vantage docs (and what the client + unit tests assume):

```jsonc
{ "name": "...", "interval": "monthly", "unit": "percent",
  "data": [ { "date": "2026-05-01", "value": "5.33" }, ... ] }
```

Client reads `data.first`, converts the percent string to a fraction (`5.33` → `0.0533`). Re-probe
FFR alone on a fresh daily quota if a live confirmation is wanted before #12.

## Surprises / notes for the recompute slice (#12)

- **Alpha Vantage monthly history is capped at ~1999-12-31.** SPY/QQQ/NVDA all start there, so
  SPY is **26.4 y, not the plan's assumed ~32 y**. Harmless: #12 caps the lookback at
  `min(20y, available)`, and 26.4 y ≥ 20 y, so SPY/AGG/QQQ/NVDA all use the full 20 y window.
- **VT is the only short-history asset (17.8 y).** It uses its full available history (< 20 y) —
  the `min(20y, available)` branch must be exercised here. Matches the plan's expectation.
- **SPY–AGG common window for the 60/40 correlation** (#12, `Monte::Portfolio`) is bounded by
  AGG's start: **2003-10-31 → present (~22.6 y)**, then further capped to 20 y. Plenty of overlap.
- Latest observation is the **previous trading day** (intra-month), not a month-end — fine for
  freshness, but month-boundary log-return math in #12 should key off the observation dates as
  returned rather than assuming calendar month-ends.

## Gate verdict

**Tickers confirmed:** SPY, VT, NVDA, AGG (+ FFR). QQQ has no asset mapping today (probed only for
coverage; available if a tech-index swap is ever wanted). **Throttle/quota confirmed:** 25/day,
1 req/s burst → #10 may proceed with a ~5-call daily refresh and conservative throttle. The one
delta to carry forward: SPY history is 26.4 y (not ~32 y), immaterial under the 20 y cap.
