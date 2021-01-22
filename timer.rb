class Timer
    def initialize(interval)
        @interval = Float(interval)
        @interval_remaining = @interval
    end

    def update(seconds_elapsed)
        @interval_remaining -= seconds_elapsed
        while @interval_remaining <= 0
            yield
            @interval_remaining += @interval
        end
    end     
end