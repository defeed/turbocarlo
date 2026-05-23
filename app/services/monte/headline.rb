module Monte
  # Builds the result headline as a Monte::Copy (segments + semantic emphasis),
  # dispatching on the scenario's headline_key. Each variant branches on the
  # actual simulation result so copy lives in version control and can never
  # contradict its own chart: the median winner picks the framing, the win rate
  # only tunes the wording within it. Robust to live-data drift — if refreshed
  # parameters flip the median, the headline flips with it.
  module Headline
    module_function

    # A win rate at or above this reads as a confident "usually wins"; below it,
    # the wording softens toward "neck and neck".
    COIN_FLIP_LOW = 55

    def call(scenario, results)
      case scenario.headline_key
      when "stocks_vs_cash" then stocks_vs_cash(results)
      when "lump_vs_dca"    then lump_vs_dca(results)
      when "invest_vs_debt" then invest_vs_debt(results)
      else
        raise ArgumentError, "no headline for #{scenario.headline_key.inspect}"
      end
    end

    def stocks_vs_cash(results)
      win = results[:win_rate_a]
      if a_wins_median?(results)
        Copy.new
          .plain("Investing beats cash in ").growth("#{win}%")
          .plain(" of futures — but loses badly in the worst ").cash("#{100 - win}%")
          .plain(".")
      else
        Copy.new
          .plain("When the dust settles, ").cash("cash")
          .plain(" comes out ahead at the midpoint — investing only wins the upside in ")
          .growth("#{win}%").plain(" of futures.")
      end
    end

    def lump_vs_dca(results)
      win = results[:win_rate_a]
      if !a_wins_median?(results)
        Copy.new
          .plain("Spreading it out actually wins the typical future here — lump sum leads in only ")
          .cash("#{win}%").plain(" of futures.")
      elsif win >= COIN_FLIP_LOW
        Copy.new
          .plain("Investing it all at once ends ahead of spreading it out in ")
          .growth("#{win}%").plain(" of futures.")
      else
        Copy.new
          .plain("All at once and spread out finish neck and neck — lump sum noses ahead in just ")
          .neutral("#{win}%").plain(" of futures.")
      end
    end

    def invest_vs_debt(results)
      win = results[:win_rate_a]
      if a_wins_median?(results)
        Copy.new
          .plain("Investing instead of clearing the debt comes out ahead in ").growth("#{win}%")
          .plain(" of futures — and behind in the other ").cash("#{100 - win}%")
          .plain(".")
      else
        Copy.new
          .plain("Clearing the debt is the surer bet — it wins the typical future, and investing pulls ahead in only ")
          .growth("#{win}%").plain(" of futures.")
      end
    end

    def a_wins_median?(results)
      results[:median_a] >= results[:median_b]
    end
  end
end
