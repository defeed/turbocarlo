namespace :market_data do
  # The Phase 3 gate (issue #8). Probes Alpha Vantage on the real free-tier key
  # to confirm — before the refresh job (#10) commits to tickers and a throttle —
  # the monthly-adjusted response shape, per-symbol history coverage, and the
  # current daily request limit. HITL: a human reads the output and records the
  # findings in docs/market-data-probe.md. Hits the live API; writes no DB rows.
  #
  #   bin/rails market_data:probe
  desc "Probe Alpha Vantage for symbol coverage + rate limit (gate, issue #8)"
  task probe: :environment do
    symbols = %w[VT SPY QQQ NVDA AGG]
    throttle = Integer(ENV.fetch("PROBE_THROTTLE", "12")) # seconds between calls
    client = MarketData::AlphaVantageClient.new

    puts "Alpha Vantage probe — #{Time.current.utc.iso8601} (throttle #{throttle}s between calls)"
    puts "=" * 72

    calls = 0
    symbols.each do |symbol|
      calls += 1
      print "[#{calls}] #{symbol} monthly-adjusted ... "
      obs = client.monthly_adjusted(symbol)
      first, last = obs.last, obs.first # newest-first => last is earliest
      years = ((last[:observed_on] - first[:observed_on]).to_i / 365.25).round(1)
      puts "OK"
      puts "      observations : #{obs.length}"
      puts "      earliest     : #{first[:observed_on]}  (#{years}y of history)"
      puts "      latest       : #{last[:observed_on]}  adj close #{last[:close]}"
      puts "      obs keys      : #{obs.first.keys.inspect}"
    rescue MarketData::AlphaVantageClient::RateLimitError => e
      puts "RATE-LIMITED after #{calls} call(s)"
      puts "      message: #{e.message}"
      puts "      ^ this is the gate finding: the daily limit is ~#{calls - 1} successful call(s)."
      break
    rescue MarketData::AlphaVantageClient::Error => e
      puts "ERROR: #{e.class.name.demodulize} — #{e.message}"
    ensure
      sleep throttle if symbol != symbols.last
    end

    puts "-" * 72
    print "[ffr] FEDERAL_FUNDS_RATE monthly ... "
    begin
      ffr = client.federal_funds_rate
      puts "OK"
      puts "      latest rate  : #{(ffr[:rate] * 100).round(2)}%  as of #{ffr[:observed_on]}"
    rescue MarketData::AlphaVantageClient::Error => e
      puts "#{e.class.name.demodulize} — #{e.message}"
    end

    puts "=" * 72
    puts "Done. Record findings in docs/market-data-probe.md."
  end
end
