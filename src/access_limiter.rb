mutex = Mutex.new :global => true

class AccessLimiter
  def initialize
    @current_time = Time.new.localtime.to_i
    @counter_kvs = Cache.new :namespace => "smtp_access_limiter"
    @counter_key = config[:target]
    raise "config[:target] is nil" unless @counter_key
    @interval_time = config[:interval_time]
    raise "config[:interval_time] is nil" unless config[:interval_time]
  end

  def cleanup
    ctime = @counter_kvs["create_time_#{@counter_key}"].to_i
    return false if ctime == 0
    if (@create_time - ctime) > @interval_time
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
    counter_kvs[@counter_key] = (cur + 1).to_s
  end
end
