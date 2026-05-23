module ApplicationHelper
  # Whole-unit money in the scenario's currency, e.g. "€69,900".
  def money(value, currency)
    "#{currency}#{number_with_delimiter(value.round)}"
  end

  def eyebrow(currency, amount, horizon)
    "#{money(amount, currency)} · #{pluralize(horizon, "year")}"
  end
end
