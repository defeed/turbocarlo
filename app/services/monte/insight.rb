module Monte
  # Builds the result insight as a Monte::Copy, dispatching on the scenario's
  # insight_key. Where the headline frames the comparison by win rate, the insight
  # takes a different angle — the downside, the dispersion, or the "why" — using
  # money figures from the same frozen snapshot. It branches median-first like the
  # headline so it cannot contradict the chart. `amount` is the starting capital
  # (the result hash doesn't carry it).
  module Insight
    module_function

    def call(scenario, results, amount:)
      case scenario.insight_key
      when "stocks_vs_cash" then stocks_vs_cash(results, amount)
      when "lump_vs_dca"    then lump_vs_dca(results)
      when "invest_vs_debt" then invest_vs_debt(results)
      else
        raise ArgumentError, "no insight for #{scenario.insight_key.inspect}"
      end
    end

    def stocks_vs_cash(results, amount)
      if !a_wins_median?(results)
        Copy.new
          .plain("On these numbers the safe option's typical ").money(results[:median_b], emphasis: :cash)
          .plain(" edges out investing's ").money(results[:median_a], emphasis: :growth)
          .plain(" — the premium for taking risk has thinned.")
      elsif results[:p5_a] < amount
        Copy.new
          .plain("In the worst 5% of futures, investing leaves you with about ")
          .money(results[:p5_a], emphasis: :cash)
          .plain(" — below the ").money(amount, emphasis: :neutral)
          .plain(" you started with. Cash never does that.")
      else
        Copy.new
          .plain("Even in a bad run investing roughly holds its value, at ")
          .money(results[:p5_a], emphasis: :neutral)
          .plain(" — though in those futures plain savings would have done a little better.")
      end
    end

    def lump_vs_dca(results)
      if a_wins_median?(results)
        Copy.new
          .plain("The edge is small, and it comes from time in the market — both tails land close, from ")
          .money(results[:p5_a], emphasis: :growth).plain(" to ").money(results[:p95_a], emphasis: :growth)
          .plain(". Investing in one go simply puts every euro to work sooner than averaging in over a year.")
      else
        Copy.new
          .plain("Here the slow approach won — averaging in landed a typical ")
          .money(results[:median_b], emphasis: :cash)
          .plain(", ahead of going all-in. In a market that fell early, staying partly in cash softened the entry.")
      end
    end

    def invest_vs_debt(results)
      if results[:p5_a] >= results[:median_b]
        Copy.new
          .plain("Even investing's rough futures (").money(results[:p5_a], emphasis: :neutral)
          .plain(") clear the bar set by paying off the debt (").money(results[:median_b], emphasis: :neutral)
          .plain(") — the maths favours keeping the loan and investing.")
      else
        Copy.new
          .plain("Paying off the debt is a guaranteed return. Investing might beat it — its typical future is ")
          .money(results[:median_a], emphasis: :growth)
          .plain(" — but in a bad run you'd end near ").money(results[:p5_a], emphasis: :cash)
          .plain(", behind the ").money(results[:median_b], emphasis: :neutral)
          .plain(" that simply clearing the loan locks in.")
      end
    end

    def a_wins_median?(results)
      results[:median_a] >= results[:median_b]
    end
  end
end
