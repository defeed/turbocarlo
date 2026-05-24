require "test_helper"

class Monte::StatisticsTest < ActiveSupport::TestCase
  test "mean averages the series" do
    assert_in_delta 3.0, Monte::Statistics.mean([ 1, 2, 3, 4, 5 ]), 1e-12
  end

  test "sample_stddev uses the n-1 denominator" do
    # variance = ((1-3)²+(2-3)²+(3-3)²+(4-3)²+(5-3)²)/4 = 10/4 = 2.5
    assert_in_delta Math.sqrt(2.5), Monte::Statistics.sample_stddev([ 1, 2, 3, 4, 5 ]), 1e-12
  end

  test "sample_stddev needs at least two values" do
    assert_raises(ArgumentError) { Monte::Statistics.sample_stddev([ 1 ]) }
  end

  test "correlation is +1 for a perfectly increasing linear relationship" do
    assert_in_delta 1.0, Monte::Statistics.correlation([ 1, 2, 3, 4 ], [ 2, 4, 6, 8 ]), 1e-12
  end

  test "correlation is -1 for a perfectly decreasing linear relationship" do
    assert_in_delta(-1.0, Monte::Statistics.correlation([ 1, 2, 3, 4 ], [ 8, 6, 4, 2 ]), 1e-12)
  end

  test "correlation of a flat series is zero (no linear relationship)" do
    assert_equal 0.0, Monte::Statistics.correlation([ 1, 2, 3 ], [ 5, 5, 5 ])
  end

  test "correlation requires equal-length series" do
    assert_raises(ArgumentError) { Monte::Statistics.correlation([ 1, 2 ], [ 1, 2, 3 ]) }
  end
end
