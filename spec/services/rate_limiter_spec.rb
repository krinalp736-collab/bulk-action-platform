require "rails_helper"

RSpec.describe RateLimiter do
  def limiter(account_id = SecureRandom.hex(6))
    described_class.new(account_id)
  end

  it "allows a request comfortably under the limit" do
    expect(limiter.allow?(100)).to be(true)
  end

  it "allows exactly up to the limit and rejects the next unit over" do
    rl = limiter
    expect(rl.allow?(described_class::LIMIT)).to be(true)
    expect(rl.allow?(1)).to be(false)
  end

  it "does not reserve quota for a rejected request" do
    rl = limiter
    expect(rl.allow?(described_class::LIMIT - 10)).to be(true)
    expect(rl.allow?(20)).to be(false) # would push 10 over the limit — rejected

    # If the rejected call above had reserved quota anyway, exactly the
    # remaining 10 units would no longer fit. It still does, proving a
    # rejection never touched the counter.
    expect(rl.allow?(10)).to be(true)
  end

  it "blends the previous window's count into the estimate near a window boundary" do
    account_id = SecureRandom.hex(6)
    base = Time.current.beginning_of_minute

    travel_to(base) { limiter(account_id).allow?(described_class::LIMIT) }

    travel_to(base + 65) do
      expect(limiter(account_id).allow?(described_class::LIMIT)).to be(false)
    end
  end

  it "lets a fresh window fully reopen once the previous window's influence fades" do
    account_id = SecureRandom.hex(6)
    base = Time.current.beginning_of_minute

    travel_to(base) { limiter(account_id).allow?(described_class::LIMIT) }

    travel_to(base + 130) do
      expect(limiter(account_id).allow?(described_class::LIMIT)).to be(true)
    end
  end

  describe ".seconds_until_next_window" do
    it "returns the seconds remaining in the current minute" do
      travel_to(Time.current.beginning_of_minute + 45) do
        expect(described_class.seconds_until_next_window).to eq(15)
      end
    end
  end
end
