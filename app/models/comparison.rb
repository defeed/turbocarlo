require "digest"

class Comparison < ApplicationRecord
  N_PATHS = 500
  SNAPSHOT_PRECISION = 6

  belongs_to :scenario

  validates :slug, :dedup_key, presence: true, uniqueness: true
  validates :amount, :horizon_years, :seed, presence: true

  # A Comparison is immutable once created: its result is frozen against the
  # snapshot taken at creation. Re-rendering /r/:slug reads only this row, never
  # live Asset params (ADR-0002).
  class << self
    # Snapshot the scenario's current Asset params, derive a deterministic
    # dedup_key + seed from (scenario, amount, horizon, rounded snapshot), and
    # find-or-create the canonical row. Runs the simulator exactly once, on create.
    def find_or_run!(scenario:, amount:, horizon:)
      a = scenario.path_a
      b = scenario.path_b
      mu_a, sigma_a = rounded(a.asset.current_params)
      mu_b, sigma_b = rounded(b.asset.current_params)

      key = dedup_key_for(scenario.slug, amount, horizon, mu_a, sigma_a, mu_b, sigma_b)

      existing = find_by(dedup_key: key)
      return existing if existing

      create!(
        scenario: scenario,
        slug: Nanoid.generate(size: 12),
        dedup_key: key,
        amount: amount,
        horizon_years: horizon,
        seed: seed_from(key),
        mu_a_snapshot: mu_a,
        sigma_a_snapshot: sigma_a,
        mu_b_snapshot: mu_b,
        sigma_b_snapshot: sigma_b,
        data_as_of: Date.current,
        results_json: run_simulation(amount, horizon, seed_from(key), mu_a, sigma_a, mu_b, sigma_b)
      )
    rescue ActiveRecord::RecordNotUnique
      # Lost a race on dedup_key — the canonical row already exists.
      find_by!(dedup_key: key)
    end

    private

    def rounded(params)
      [ params[:mu].round(SNAPSHOT_PRECISION), params[:sigma].round(SNAPSHOT_PRECISION) ]
    end

    def dedup_key_for(*parts)
      Digest::SHA256.hexdigest(parts.join("|"))
    end

    # 15 hex chars (60 bits) keeps the derived seed within SQLite's signed
    # 64-bit integer range while staying deterministic per dedup_key.
    def seed_from(key)
      key[0, 15].to_i(16)
    end

    def run_simulation(amount, horizon, seed, mu_a, sigma_a, mu_b, sigma_b)
      Monte::Simulator.new(amount: amount, horizon: horizon, seed: seed, n_paths: N_PATHS).call(
        path_a: { mu: mu_a, sigma: sigma_a },
        path_b: { mu: mu_b, sigma: sigma_b }
      )
    end
  end

  # The frozen result hash, with symbol keys regardless of JSON round-tripping.
  def results
    results_json.deep_symbolize_keys
  end
end
