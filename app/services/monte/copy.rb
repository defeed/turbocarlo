module Monte
  # A pure, Rails-free representation of result copy: an ordered list of segments,
  # each a piece of text optionally tagged with a semantic emphasis role (:growth
  # = Path A, :cash = Path B, :neutral). Monte::Headline and Monte::Insight build
  # one of these; the view (ApplicationHelper#copy_tag) renders the <span> markup.
  # This keeps the copy *and* its emphasis in version control while leaving HTML
  # out of the engine.
  #
  # Money segments carry a raw numeric value plus money: true, so the view formats
  # them through the same ApplicationHelper#money the rest of the page uses — the
  # engine decides *which* number to show, never how to format currency.
  #
  #   Monte::Copy.new
  #     .plain("Investing beats cash in ")
  #     .growth("63%")
  #     .plain(" of futures.")
  class Copy
    Segment = Data.define(:value, :emphasis, :money)

    attr_reader :segments

    def initialize
      @segments = []
    end

    def plain(text)   = add(text, nil)
    def growth(text)  = add(text, :growth)
    def cash(text)    = add(text, :cash)
    def neutral(text) = add(text, :neutral)

    # A currency amount to be formatted by the view, optionally emphasised.
    def money(value, emphasis: nil)
      @segments << Segment.new(value, emphasis, true)
      self
    end

    # Plain-text rendering — the view's fallback and what unit tests assert on.
    def to_s
      segments.map { |s| s.value.to_s }.join
    end

    private

    def add(text, emphasis)
      @segments << Segment.new(text, emphasis, false)
      self
    end
  end
end
