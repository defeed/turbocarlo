import { Controller } from "@hotwired/stimulus"

// Fan-of-futures chart. Refactored from the prototype's drawChart: a soft
// p5–p95 envelope, faint sampled paths (spaghetti), two bold median lines,
// a dashed start line, and y-axis labels. All data comes pre-snapshotted from
// the frozen Comparison row via data-chart-data-value.
//
//   data-chart-data-value     => { band_a, band_b, sample_a, sample_b }
//   data-chart-amount-value   => starting amount (start line)
//   data-chart-currency-value => prefix symbol for y-axis labels, e.g. "€"
export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object, amount: Number, currency: String }

  // Path A is the growth/active side (green), Path B the stable side (orange).
  static GREEN = "45, 90, 61"
  static ORANGE = "184, 97, 46"

  connect() {
    this.draw()
    this.resizeObserver = new ResizeObserver(() => this.draw())
    this.resizeObserver.observe(this.canvasTarget)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  draw() {
    const canvas = this.canvasTarget
    const rect = canvas.getBoundingClientRect()
    if (rect.width === 0 || rect.height === 0) return

    const dpr = window.devicePixelRatio || 1
    canvas.width = rect.width * dpr
    canvas.height = rect.height * dpr
    const ctx = canvas.getContext("2d")
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, rect.width, rect.height)

    const { band_a: bandA, band_b: bandB, sample_a: sampleA, sample_b: sampleB } = this.dataValue
    if (!bandA || !bandB) return // nothing to draw (e.g. a legacy snapshot without chart data)
    const w = rect.width
    const h = rect.height
    const padding = { top: 12, right: 8, bottom: 18, left: 36 }
    const plotW = w - padding.left - padding.right
    const plotH = h - padding.top - padding.bottom

    // y-scale from the bands (already outlier-trimmed) plus the start amount.
    let yMax = Math.max(...bandA.p95, ...bandB.p95, this.amountValue)
    let yMin = Math.min(...bandA.p5, ...bandB.p5, this.amountValue)
    yMax *= 1.05
    yMin = Math.min(yMin, this.amountValue * 0.7)

    const steps = bandA.median.length - 1
    const px = (t) => padding.left + (plotW * t) / steps
    const py = (v) => padding.top + (plotH * (yMax - v)) / (yMax - yMin)

    this.drawAxes(ctx, padding, plotW, yMin, yMax, py)
    this.drawStartLine(ctx, padding, plotW, py)

    // Soft envelope behind everything (B under A, matching the prototype).
    this.drawBand(ctx, bandB, px, py, `rgba(${this.constructor.ORANGE}, 0.07)`)
    this.drawBand(ctx, bandA, px, py, `rgba(${this.constructor.GREEN}, 0.07)`)

    // Faint individual paths.
    this.drawSpaghetti(ctx, sampleB, px, py, `rgba(${this.constructor.ORANGE}, 0.12)`)
    this.drawSpaghetti(ctx, sampleA, px, py, `rgba(${this.constructor.GREEN}, 0.13)`)

    // Bold median lines on top.
    this.drawMedian(ctx, bandB.median, px, py, "#b8612e")
    this.drawMedian(ctx, bandA.median, px, py, "#2d5a3d")
  }

  drawAxes(ctx, padding, plotW, yMin, yMax, py) {
    ctx.fillStyle = "#7a7568"
    ctx.font = "9px 'JetBrains Mono', monospace"
    ctx.textAlign = "right"
    const ySteps = 4
    for (let i = 0; i <= ySteps; i++) {
      const v = yMin + ((yMax - yMin) * i) / ySteps
      const y = py(v)
      ctx.strokeStyle = "rgba(0, 0, 0, 0.04)"
      ctx.beginPath()
      ctx.moveTo(padding.left, y)
      ctx.lineTo(padding.left + plotW, y)
      ctx.stroke()
      ctx.fillText(this.formatMoney(v), padding.left - 4, y + 3)
    }
  }

  drawStartLine(ctx, padding, plotW, py) {
    const y = py(this.amountValue)
    ctx.strokeStyle = "rgba(0, 0, 0, 0.18)"
    ctx.setLineDash([3, 3])
    ctx.beginPath()
    ctx.moveTo(padding.left, y)
    ctx.lineTo(padding.left + plotW, y)
    ctx.stroke()
    ctx.setLineDash([])
  }

  drawBand(ctx, band, px, py, fillStyle) {
    ctx.fillStyle = fillStyle
    ctx.beginPath()
    band.p95.forEach((v, t) => {
      const x = px(t)
      const y = py(v)
      t === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    for (let t = band.p5.length - 1; t >= 0; t--) {
      ctx.lineTo(px(t), py(band.p5[t]))
    }
    ctx.closePath()
    ctx.fill()
  }

  drawSpaghetti(ctx, paths, px, py, strokeStyle) {
    ctx.strokeStyle = strokeStyle
    ctx.lineWidth = 0.6
    for (const path of paths) {
      ctx.beginPath()
      path.forEach((v, t) => {
        const x = px(t)
        const y = py(v)
        t === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
      })
      ctx.stroke()
    }
  }

  drawMedian(ctx, median, px, py, strokeStyle) {
    ctx.strokeStyle = strokeStyle
    ctx.lineWidth = 2.5
    ctx.lineCap = "round"
    ctx.beginPath()
    median.forEach((v, t) => {
      const x = px(t)
      const y = py(v)
      t === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()
  }

  // Compact currency label, e.g. "€50k" / "€1.2M".
  formatMoney(value) {
    const symbol = this.currencyValue
    const abs = Math.abs(value)
    if (abs >= 1e6) return `${symbol}${(value / 1e6).toFixed(1)}M`
    if (abs >= 1e3) return `${symbol}${Math.round(value / 1e3)}k`
    return `${symbol}${Math.round(value)}`
  }
}
