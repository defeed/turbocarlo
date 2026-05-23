module Monte
  # Builds the result headline sentence. Dispatches on the scenario's
  # headline_key so copy lives in version control and can branch on the actual
  # simulation result. These are the single-variant headlines each scenario needs
  # to render; the richer result-branching variants and Monte::Insight land in a
  # later slice. Each is win-rate / median driven so it cannot contradict its chart.
  module Headline
    module_function

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
      "Investing beats cash in #{win}% of futures — " \
        "but loses badly in the worst #{100 - win}%."
    end

    def lump_vs_dca(results)
      win = results[:win_rate_a]
      "Investing it all at once ends ahead of spreading it out " \
        "in #{win}% of futures."
    end

    def invest_vs_debt(results)
      win = results[:win_rate_a]
      "Investing instead of clearing the debt comes out ahead " \
        "in #{win}% of futures — and behind in the other #{100 - win}%."
    end
  end
end
