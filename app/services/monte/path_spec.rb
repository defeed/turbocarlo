module Monte
  # One side of a comparison, described to the engine: the asset's drift/volatility
  # plus the behavior that turns a market path into a wealth path. A plain value
  # object — zero Rails deps — so the simulator takes structured specs rather than
  # bare (mu, sigma) pairs and can grow new behaviors without changing its signature.
  #
  #   Monte::PathSpec.new(mu: 0.08, sigma: 0.16, behavior: :plain, label: "S&P 500")
  #   Monte::PathSpec.new(mu: 0.08, sigma: 0.16, behavior: :debt_adjusted,
  #                       behavior_params: { debt_rate: 0.06 })
  PathSpec = Data.define(:mu, :sigma, :behavior, :behavior_params, :label) do
    def initialize(mu:, sigma:, behavior: :plain, behavior_params: {}, label: nil)
      super(
        mu: mu.to_f,
        sigma: sigma.to_f,
        behavior: behavior.to_sym,
        behavior_params: (behavior_params || {}).transform_keys(&:to_sym),
        label: label
      )
    end

    # A deterministic path consumes no random draws and needs no sampling.
    def deterministic?
      sigma.zero?
    end
  end
end
