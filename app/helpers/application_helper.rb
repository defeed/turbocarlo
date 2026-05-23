module ApplicationHelper
  # Tailwind classes for each Monte::Copy emphasis role. No `text-neutral`
  # utility is compiled, so neutral leans on weight against the ink colour.
  COPY_EMPHASIS_CLASSES = {
    growth: "text-growth font-semibold",
    cash: "text-cash font-semibold",
    neutral: "font-semibold text-ink"
  }.freeze

  # Whole-unit money in the scenario's currency, e.g. "€69,900".
  def money(value, currency)
    "#{currency}#{number_with_delimiter(value.round)}"
  end

  # Render a Monte::Copy (headline / insight) to safe HTML: emphasised segments
  # become coloured <span>s, money segments are formatted through #money. Keeps
  # the copy modules Rails-free — they decide the words and the emphasis, the
  # view owns the markup and currency formatting.
  def copy_tag(copy, currency:)
    safe_join(copy.segments.map { |segment|
      text = segment.money ? money(segment.value, currency) : segment.value
      if segment.emphasis
        content_tag(:span, text, class: COPY_EMPHASIS_CLASSES.fetch(segment.emphasis))
      else
        text
      end
    })
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
