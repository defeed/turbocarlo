module Monte
  # Turns one market path into one wealth path, applying a PathSpec's behavior.
  # Pure and Rails-free: the Simulator pre-draws the standard-normal sequence and
  # hands it in, so this object never touches an RNG. That seam is deliberate —
  # common-random-numbers coupling (#9) is then a Simulator-only change: it just
  # feeds the *same* `normals` to both sides.
  #
  # Every behavior compounds off the same exp-GBM market-growth factor, so the
  # arithmetic is consistent across behaviors (unlike the prototype, which mixed
  # simple and exact compounding). Returns the full series
  # [amount, w₁, …, w_steps], pinned at `amount` at t=0 so the fan starts at "Now".
  class Path
    # @param spec    [Monte::PathSpec]
    # @param amount  [Float] the starting amount
    # @param steps   [Integer] number of monthly steps
    # @param dt      [Float] year-fraction per step (horizon / steps)
    # @param normals [Array<Float>, nil] `steps` standard normals; ignored when σ == 0
    def self.build(spec:, amount:, steps:, dt:, normals:)
      new(spec, amount.to_f, steps, dt).build(normals)
    end

    def initialize(spec, amount, steps, dt)
      @spec = spec
      @amount = amount
      @steps = steps
      @dt = dt
    end

    def build(normals)
      growth = growth_series(normals)

      case @spec.behavior
      when :plain         then plain(growth)
      when :dca           then dca(growth)
      when :debt_adjusted then debt_adjusted(growth)
      else
        raise ArgumentError, "unknown behavior #{@spec.behavior.inspect}"
      end
    end

    private

    # Cumulative growth of one unit of the underlying market, growth[0] = 1.
    # A zero-volatility asset compounds deterministically (no draws consumed).
    def growth_series(normals)
      drift = (@spec.mu - 0.5 * @spec.sigma**2) * @dt
      diffusion = @spec.sigma * Math.sqrt(@dt)
      deterministic_factor = Math.exp(@spec.mu * @dt)

      growth = Array.new(@steps + 1)
      growth[0] = 1.0
      g = 1.0
      @steps.times do |t|
        g *= if @spec.deterministic?
          deterministic_factor
        else
          Math.exp(drift + diffusion * normals[t])
        end
        growth[t + 1] = g
      end
      growth
    end

    # Lump sum: the whole amount rides the market from t=0.
    def plain(growth)
      growth.map { |g| @amount * g }
    end

    # Dollar-cost averaging: invest amount/12 at the start of each of the first
    # 12 months; tranches not yet invested sit as cash at 0%. Each invested
    # tranche grows by the market factor since its own entry month.
    def dca(growth)
      months = [ 12, @steps ].min
      tranche = @amount / 12.0

      (0..@steps).map do |t|
        wealth = 0.0
        months.times do |k|
          wealth += if k <= t
            tranche * (growth[t] / growth[k]) # invested at month k
          else
            tranche # still cash, earning nothing
          end
        end
        wealth
      end
    end

    # Keep the money invested instead of clearing a loan: net wealth is the
    # invested value minus the interest the unpaid balance keeps accruing.
    def debt_adjusted(growth)
      rate = @spec.behavior_params.fetch(:debt_rate)

      (0..@steps).map do |t|
        invested = @amount * growth[t]
        debt = @amount * (1.0 + rate)**(t * @dt)
        accrued_interest = debt - @amount
        invested - accrued_interest
      end
    end
  end
end
