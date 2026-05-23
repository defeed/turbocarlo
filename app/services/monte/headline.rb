module Monte
  # Builds the result headline sentence. Dispatches on the scenario's
  # headline_key so copy lives in version control and can branch on the actual
  # simulation result. This slice ships the one "stocks_vs_cash" branch; later
  # slices add the remaining scenarios and the result-branching variants.
  module Headline
    module_function

    def call(scenario, results)
      case scenario.headline_key
      when "stocks_vs_cash"
        stocks_vs_cash(results)
      else
        raise ArgumentError, "no headline for #{scenario.headline_key.inspect}"
      end
    end

    def stocks_vs_cash(results)
      win = results[:win_rate_a]
      "Investing beats cash in #{win}% of futures — " \
        "but loses badly in the worst #{100 - win}%."
    end
  end
end
