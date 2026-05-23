require "test_helper"

module Monte
  class CopyTest < ActiveSupport::TestCase
    test "appends segments in order with their emphasis roles" do
      copy = Copy.new.plain("a ").growth("b").cash(" c").neutral(" d")
      assert_equal [ nil, :growth, :cash, :neutral ], copy.segments.map(&:emphasis)
      assert_equal "a b c d", copy.to_s
    end

    test "money segments carry a raw numeric value flagged for view formatting" do
      copy = Copy.new.money(50_000, emphasis: :growth)
      segment = copy.segments.sole
      assert segment.money
      assert_equal 50_000, segment.value
      assert_equal :growth, segment.emphasis
    end

    test "to_s joins the raw values as a plain-text fallback" do
      copy = Copy.new.plain("worth ").money(70_000).plain(" today")
      assert_equal "worth 70000 today", copy.to_s
    end

    test "builder methods chain" do
      copy = Copy.new
      assert_same copy, copy.plain("x")
      assert_same copy, copy.money(1)
    end
  end
end
