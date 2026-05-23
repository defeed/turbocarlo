require "application_system_test_case"

class ResultChartTest < ApplicationSystemTestCase
  test "the fan chart canvas renders with non-zero dimensions" do
    scenario = seed_decision_lab!
    comparison = Comparison.find_or_run!(scenario: scenario, amount: 50_000, horizon: 5)

    visit result_path(comparison.slug)

    assert_selector "canvas[data-chart-target='canvas']"
    width = evaluate_script("document.querySelector('[data-chart-target=\"canvas\"]').width")
    height = evaluate_script("document.querySelector('[data-chart-target=\"canvas\"]').height")
    assert_operator width.to_i, :>, 0
    assert_operator height.to_i, :>, 0

    # The drawing logic ran without throwing (a JS error in connect/draw would
    # otherwise pass silently).
    severe = page.driver.browser.logs.get(:browser).select { |entry| entry.level == "SEVERE" }
    assert_empty severe, "expected no severe browser console errors, got: #{severe.map(&:message)}"
  end
end
