module Monte
  # Pure Monte Carlo engine — zero Rails dependencies, seeded, deterministic.
  #
  # Simulates two GBM-driven paths from structured PathSpecs (each carrying a
  # behavior — plain / DCA / debt-adjusted) and returns summary statistics plus
  # the per-step data the fan-of-futures chart needs. Draws are independent per
  # side by default; when `coupled` (the two paths ride the same underlying, e.g.
  # lump-sum vs DCA on the same S&P), both sides consume the *same* per-simulation
  # Z-sequence so the comparison is apples-to-apples (ADR-0001). The win rate is
  # only meaningful under coupling for same-underlying scenarios.
  #
  #   Monte::Simulator.new(amount: 50_000, horizon: 5, seed: 123).call(
  #     spec_a: Monte::PathSpec.new(mu: 0.08, sigma: 0.16),
  #     spec_b: Monte::PathSpec.new(mu: 0.045, sigma: 0.005)
  #   )
  #   # => { median_a:, median_b:, p5_a:, p95_a:, p5_b:, p95_b:, win_rate_a:, steps:,
  #   #      chart: { band_a:, band_b:, sample_a:, sample_b: } }
  #
  # The chart payload is snapshotted into the frozen Comparison row so the
  # permalink reproduces its original fan: per-step p5/median/p95 bands computed
  # from all paths, plus a small sample of whole paths for the faint spaghetti.
  class Simulator
    # Whole paths kept per side for the chart's spaghetti texture. The envelope
    # and median line use the bands (computed from all paths), not this sample.
    SAMPLE_SIZE = 40

    def initialize(amount:, horizon:, seed:, n_paths: 500, coupled: false)
      @amount = amount.to_f
      @horizon = horizon
      @seed = seed
      @n_paths = n_paths
      @coupled = coupled
      @steps = [ horizon * 12, 120 ].min
      @dt = horizon.to_f / @steps
    end

    def call(spec_a:, spec_b:)
      rng = Random.new(@seed)
      paths_a = Array.new(@n_paths)
      paths_b = Array.new(@n_paths)

      @n_paths.times do |i|
        if @coupled
          # Both sides ride the same per-simulation market (ADR-0001): one shared
          # Z-sequence, independent across simulations. A deterministic (σ=0) spec
          # ignores the supplied normals in Monte::Path.
          normals = draw_normals(rng)
          paths_a[i] = build_path(spec_a, normals)
          paths_b[i] = build_path(spec_b, normals)
        else
          paths_a[i] = simulate_path(spec_a, rng)
          paths_b[i] = simulate_path(spec_b, rng)
        end
      end

      finals_a = paths_a.map(&:last)
      finals_b = paths_b.map(&:last)
      wins_a = @n_paths.times.count { |i| finals_a[i] > finals_b[i] }
      sorted_a = finals_a.sort
      sorted_b = finals_b.sort

      {
        median_a: percentile(sorted_a, 0.5),
        median_b: percentile(sorted_b, 0.5),
        p5_a: percentile(sorted_a, 0.05),
        p95_a: percentile(sorted_a, 0.95),
        p5_b: percentile(sorted_b, 0.05),
        p95_b: percentile(sorted_b, 0.95),
        win_rate_a: (100.0 * wins_a / @n_paths).round,
        steps: @steps,
        chart: {
          band_a: band(paths_a),
          band_b: band(paths_b),
          sample_a: sample(paths_a),
          sample_b: sample(paths_b)
        }
      }
    end

    private

    # One wealth path as the full series [amount, w₁, …, w_steps] so the fan
    # starts pinned at "Now". Draws its own per-step standard normals (none for a
    # deterministic, zero-σ spec); used for independent (uncoupled) sides.
    def simulate_path(spec, rng)
      normals = spec.deterministic? ? nil : draw_normals(rng)
      build_path(spec, normals)
    end

    # A fresh per-step Z-sequence off the seeded RNG.
    def draw_normals(rng)
      Array.new(@steps) { standard_normal(rng) }
    end

    # Apply a spec's behavior to a (possibly shared) normals sequence.
    def build_path(spec, normals)
      Monte::Path.build(spec: spec, amount: @amount, steps: @steps, dt: @dt, normals: normals)
    end

    # Per-step p5/median/p95 envelope across every path, rounded to whole units.
    def band(paths)
      p5 = Array.new(@steps + 1)
      median = Array.new(@steps + 1)
      p95 = Array.new(@steps + 1)

      (0..@steps).each do |t|
        column = paths.map { |path| path[t] }.sort
        p5[t]     = percentile(column, 0.05).round
        median[t] = percentile(column, 0.5).round
        p95[t]    = percentile(column, 0.95).round
      end

      { p5: p5, median: median, p95: p95 }
    end

    # An evenly-strided sample of whole paths, rounded to whole units.
    def sample(paths)
      stride = (paths.length / SAMPLE_SIZE.to_f).ceil
      (0...paths.length).step(stride).map { |i| paths[i].map(&:round) }
    end

    # Box–Muller transform on the seeded RNG.
    def standard_normal(rng)
      u1 = rng.rand
      u1 = rng.rand while u1.zero?
      u2 = rng.rand
      Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
    end

    # Matches the prototype's index-based percentile (floor(n * q)).
    def percentile(sorted, quantile)
      sorted[(sorted.length * quantile).floor]
    end
  end
end
