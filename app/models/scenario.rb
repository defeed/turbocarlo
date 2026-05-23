class Scenario < ApplicationRecord
  has_many :scenario_paths, dependent: :destroy
  has_many :comparisons, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :title, :currency, :headline_key, presence: true
  validates :default_amount, :default_horizon_years, presence: true

  def path_a
    scenario_paths.find_by(role: :a)
  end

  def path_b
    scenario_paths.find_by(role: :b)
  end

  def to_param
    slug
  end
end
