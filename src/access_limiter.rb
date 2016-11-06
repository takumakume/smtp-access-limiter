global_mutex = Mutex.new :global => true

class AccessLimiter
  def initialize config
    @current_time = Time.new.localtime.to_i
    @counter_kvs = Cache.new :namespace => "smtp_access_limiter"
    @counter_key = config[:target]
    raise "config[:target] is nil" unless @counter_key
    @interval_time = config[:interval_time].to_i
    raise "config[:interval_time] is nil" unless config[:interval_time]
  end

  def cleanup
    ctime = @counter_kvs["create_time_#{@counter_key}"].to_i
    return false if ctime == 0
    if (ctime + @interval_time) < @current_time
      @counter_kvs.delete("create_time_#{@counter_key}")
      @counter_kvs.delete(@counter_key)
      true
    else
      false
    end
  end

  def current
    @counter_kvs[@counter_key]
  end

  def increment
    cur = current.to_i
    if cur == 0
      @counter_kvs["create_time_#{@counter_key}"] = @current_time.to_s
    end
    @counter_kvs[@counter_key] = (cur + 1).to_s
  end
end

###
threshold = 10
###

target = Pmilter::Session.new.envelope_to.split("@")[1]
config = {
  :target => target,
  :interval_time => 60
}
limiter = AccessLimiter.new(config)
status = limiter.cleanup
p "access_limiter: cleanup counter #{target} interval_time: #{interval_time}" if status

timeout = global_mutex.try_lock_loop(50000) do
  begin
    limiter.increment
    p "access_limiter: increment #{target} current: #{limiter.current} threshold: #{threshold}"
    if limiter.current.to_i > threshold
      p "access_limiter: reject #{target} threshold: #{threshold}"
      Pmilter.status = Pmilter::SMFIS_REJECT
    end
  rescue => e
    p "access_limiter: increment error #{e}"
  end
end
