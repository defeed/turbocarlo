require "test_helper"

module Monte
  class PathTest < ActiveSupport::TestCase
    AMOUNT = 10_000.0
    STEPS = 60
    HORIZON = 5.0
    DT = HORIZON / STEPS

    def build(spec, normals: nil)
      Path.build(spec: spec, amount: AMOUNT, steps: STEPS, dt: DT, normals: normals)
    end

    # --- plain ---------------------------------------------------------------

    test "plain is pinned at the amount and has steps + 1 points" do
      series = build(PathSpec.new(mu: 0.08, sigma: 0.16), normals: Array.new(STEPS, 0.0))
      assert_equal STEPS + 1, series.length
      assert_in_delta AMOUNT, series.first, 1e-9
    end

    test "plain with zero normals collapses to the drift-only path" do
      mu = 0.08
      sigma = 0.16
      series = build(PathSpec.new(mu: mu, sigma: sigma), normals: Array.new(STEPS, 0.0))
      # With Z = 0 the diffusion term vanishes: wealth(t) = amount·exp((μ−½σ²)·t·dt).
      expected = AMOUNT * Math.exp((mu - 0.5 * sigma**2) * HORIZON)
      assert_in_delta expected, series.last, 1e-6
    end

    # --- zero-σ --------------------------------------------------------------

    test "zero-sigma is deterministic, consumes no draws, and matches the closed form" do
      mu = 0.05
      # nil normals proves no random draw is touched on a deterministic path.
      series = build(PathSpec.new(mu: mu, sigma: 0.0), normals: nil)
      assert_in_delta AMOUNT, series.first, 1e-9
      assert_in_delta AMOUNT * Math.exp(mu * HORIZON), series.last, 1e-6
    end

    # --- dca -----------------------------------------------------------------

    test "dca on a flat (zero-growth) market holds the full amount at every step" do
      # μ = σ = 0 ⇒ the market factor is 1, so invested and uninvested tranches
      # both stay at face value: total wealth is always the starting amount.
      series = build(PathSpec.new(mu: 0.0, sigma: 0.0, behavior: :dca), normals: nil)
      series.each { |w| assert_in_delta AMOUNT, w, 1e-6 }
    end

    test "dca trails the lump sum on a rising market" do
      lump = build(PathSpec.new(mu: 0.06, sigma: 0.0, behavior: :plain), normals: nil)
      dca = build(PathSpec.new(mu: 0.06, sigma: 0.0, behavior: :dca), normals: nil)

      assert_in_delta AMOUNT, dca.first, 1e-6
      assert_operator dca.last, :<, lump.last # less time in a rising market
      assert_operator dca.last, :>, AMOUNT    # but still grows
    end

    # --- debt_adjusted -------------------------------------------------------

    test "debt-adjusted nets the invested value against accrued interest" do
      rate = 0.06
      mu = 0.10
      spec = PathSpec.new(mu: mu, sigma: 0.0, behavior: :debt_adjusted, behavior_params: { debt_rate: rate })
      series = build(spec, normals: nil)

      assert_in_delta AMOUNT, series.first, 1e-6
      invested = AMOUNT * Math.exp(mu * HORIZON)
      accrued = AMOUNT * (1.0 + rate)**HORIZON - AMOUNT
      assert_in_delta invested - accrued, series.last, 1e-6
    end

    test "debt-adjusted dips below the amount when interest outruns growth" do
      # No market growth (μ = 0) but the loan keeps accruing: net wealth must fall.
      spec = PathSpec.new(mu: 0.0, sigma: 0.0, behavior: :debt_adjusted, behavior_params: { debt_rate: 0.06 })
      series = build(spec, normals: nil)
      assert_operator series.last, :<, AMOUNT
    end

    test "an unknown behavior is rejected" do
      assert_raises(ArgumentError) do
        build(PathSpec.new(mu: 0.05, sigma: 0.1, behavior: :nonsense), normals: Array.new(STEPS, 0.0))
      end
    end
  end
end
