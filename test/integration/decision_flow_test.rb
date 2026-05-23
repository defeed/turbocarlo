require "test_helper"

class DecisionFlowTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ApplicationHelper

  setup do
    @scenario = seed_decision_lab!
    @currency = @scenario.currency
  end

  test "full flow: entry -> setup -> run -> 303 -> result permalink" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", scenario_path(@scenario), text: /Invest vs keep in savings/

    get scenario_path(@scenario)
    assert_response :success
    assert_select "form[action=?]", scenario_comparisons_path(@scenario)

    post scenario_comparisons_path(@scenario), params: { amount: 50_000, horizon: 5 }
    assert_response :see_other
    comparison = Comparison.find_by!(scenario: @scenario, amount: 50_000, horizon_years: 5)
    assert_redirected_to result_path(comparison.slug)

    follow_redirect!
    assert_response :success
    results = comparison.results

    # Eyebrow, headline, per-path median + p5/p95, and the snapshot date.
    assert_select "h1", text: /Investing beats cash in \d+% of futures/
    assert_match eyebrow(@currency, 50_000, 5), response.body
    assert_match money(results[:median_a], @currency), response.body
    assert_match money(results[:p5_a], @currency), response.body
    assert_match money(results[:p95_a], @currency), response.body
    assert_match money(results[:median_b], @currency), response.body
    assert_match comparison.data_as_of.to_fs(:long), response.body
  end

  test "the layout footer disclaimer shows on every page" do
    get root_path
    assert_select "footer", text: /not financial advice/i
  end

  test "invalid amount re-renders setup unprocessable" do
    post scenario_comparisons_path(@scenario), params: { amount: 10, horizon: 5 }
    assert_response :unprocessable_entity
    assert_select "form[action=?]", scenario_comparisons_path(@scenario)
    assert_equal 0, Comparison.count
  end

  test "reproducibility: the permalink stays frozen after live params drift" do
    post scenario_comparisons_path(@scenario), params: { amount: 50_000, horizon: 5 }
    comparison = Comparison.find_by!(scenario: @scenario)
    slug = comparison.slug

    get result_path(slug)
    body_before = response.body

    # Drift the underlying Asset μ/σ — the snapshot must win on re-render.
    @scenario.path_a.asset.update!(mu: 0.30, sigma: 0.40)

    get result_path(slug)
    assert_response :success
    assert_equal body_before, response.body, "permalink must render from the frozen snapshot"

    # A fresh run now sees drifted live params and mints a different permalink.
    post scenario_comparisons_path(@scenario), params: { amount: 50_000, horizon: 5 }
    fresh = Comparison.where.not(slug: slug).order(:created_at).last
    assert_not_nil fresh
    refute_equal slug, fresh.slug
  end

  # The special-behavior scenarios run the full flow to a rendered result page.
  test "the DCA and debt-adjusted scenarios run end-to-end to a result" do
    %w[lump-vs-dca invest-vs-debt].each do |slug|
      scenario = Scenario.find_by!(slug: slug)

      post scenario_comparisons_path(scenario),
        params: { amount: scenario.default_amount, horizon: scenario.default_horizon_years }
      assert_response :see_other
      comparison = Comparison.find_by!(scenario: scenario)

      follow_redirect!
      assert_response :success
      results = comparison.results
      # Headline renders (no missing branch) and both medians are present.
      assert_select "h1", text: /futures/i
      assert_match money(results[:median_a], scenario.currency), response.body
      assert_match money(results[:median_b], scenario.currency), response.body
    end
  end
end
