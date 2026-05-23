class ResultsController < ApplicationController
  # Renders /r/:slug entirely from the frozen Comparison row — never from live
  # Asset params — so a shared link reproduces its original numbers.
  def show
    @comparison = Comparison.find_by!(slug: params[:slug])
    @scenario = @comparison.scenario
    @results = @comparison.results
  end
end
