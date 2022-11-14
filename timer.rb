module Timer
		class Looping
			attr_writer :interval
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

    class OneShot
        def initialize(interval)
            @remaining = interval
        end

        def update(seconds_elapsed)
            if @remaining >= 0
            @remaining -= seconds_elapsed
            yield if @remaining <= 0 
            end
        end
    end    
end