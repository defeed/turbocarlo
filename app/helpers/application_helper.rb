module ApplicationHelper
  # Whole-unit money in the scenario's currency, e.g. "€69,900".
  def money(value, currency)
    "#{currency}#{number_with_delimiter(value.round)}"
  end

  def eyebrow(currency, amount, horizon)
    "#{money(amount, currency)} · #{pluralize(horizon, "year")}"
  end

  # Percentage offsets for a distribution bar drawn on a shared [min, max] scale:
  # where the p5–p95 band starts, how wide it is, and where the median tick sits.
  def dist_bar_geometry(p5, median, p95, min, max)
    span = (max - min).to_f
    return { left: 0.0, width: 100.0, median: 50.0 } if span.zero?

    {
      left: ((p5 - min) / span) * 100,
      width: ((p95 - p5) / span) * 100,
      median: ((median - min) / span) * 100
    }
  end
end
