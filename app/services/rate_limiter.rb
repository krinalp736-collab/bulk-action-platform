# Per-account rate limit on how many bulk-action rows can be processed per
# minute (default 10k, ENV-configurable). Checked once per BATCH (not per
# row) by BulkActionBatchJob — batches, not individual events, are the
# throttled unit. Worst case this under-throttles by up to (batch_size - 1)
# rows in a given window; splitting a batch to fill the remaining quota
# exactly was judged not worth the added complexity for this system.
class RateLimiter
  LIMIT = ENV.fetch("BULK_ACTION_RATE_LIMIT_PER_MINUTE", 10_000).to_i
  WINDOW_SECONDS = 60
  KEY_TTL_SECONDS = 120

  def self.redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  def initialize(account_id, redis: self.class.redis)
    @account_id = account_id
    @redis = redis
  end

  def self.seconds_until_next_window
    WINDOW_SECONDS - (Time.current.to_i % WINDOW_SECONDS)
  end

  # Sliding-window APPROXIMATION: weights the previous minute's count by how
  # much of it still "counts" toward now, which removes a hard fixed-window's
  # boundary double-burst without the memory cost of a true sliding log
  # (tracking every individual event timestamp — unnecessary at this volume).
  # Returns true (and reserves the quota) or false (caller should back off).
  def allow?(amount)
    now = Time.current
    elapsed_in_window = now.to_i % WINDOW_SECONDS

    current = redis.get(key_for(now)).to_i
    previous = redis.get(key_for(now - WINDOW_SECONDS)).to_i
    estimated = (previous * ((WINDOW_SECONDS - elapsed_in_window) / WINDOW_SECONDS.to_f)) + current

    return false if estimated + amount > LIMIT

    key = key_for(now)
    redis.multi do |pipeline|
      pipeline.incrby(key, amount)
      pipeline.expire(key, KEY_TTL_SECONDS)
    end
    true
  end

  private

  attr_reader :account_id, :redis

  def key_for(time)
    "rl:#{account_id}:#{time.to_i / WINDOW_SECONDS}"
  end
end
