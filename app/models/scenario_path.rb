class ScenarioPath < ApplicationRecord
  belongs_to :scenario
  belongs_to :asset

  # Path A is the growth/active side, Path B the stable/conservative side.
  enum :role, { a: 0, b: 1 }
  # Only :plain is exercised in this slice; :dca / :debt_adjusted arrive in Phase 1.
  enum :behavior, { plain: 0, dca: 1, debt_adjusted: 2 }

  validates :label, presence: true
  validates :role, uniqueness: { scope: :scenario_id }
end
