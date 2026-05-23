class ScenariosController < ApplicationController
  HORIZONS = [ 1, 3, 5, 10, 20 ].freeze

  def index
    @scenarios = Scenario.all
  end

  def show
    @scenario = Scenario.find_by!(slug: params[:slug])
    @horizons = HORIZONS
  end
end
