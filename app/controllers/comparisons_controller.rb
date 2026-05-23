class ComparisonsController < ApplicationController
  def create
    @scenario = Scenario.find_by!(slug: params[:slug])
    amount = Integer(params[:amount], exception: false)
    horizon = Integer(params[:horizon], exception: false)

    unless valid?(amount, horizon)
      @horizons = ScenariosController::HORIZONS
      flash.now[:alert] = "Enter an amount between 1,000 and 10,000,000 and pick a horizon."
      return render "scenarios/show", status: :unprocessable_entity
    end

    comparison = Comparison.find_or_run!(scenario: @scenario, amount: amount, horizon: horizon)
    redirect_to result_path(comparison.slug), status: :see_other
  end

  private

  def valid?(amount, horizon)
    amount && amount.between?(1_000, 10_000_000) &&
      ScenariosController::HORIZONS.include?(horizon)
  end
end
