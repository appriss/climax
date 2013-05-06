require 'drb/drb'

module Climax
  class ControlServer

    def initialize(app)
      @app = app
    end

    attr_reader :app

    def log_level
      app.log_level
    end

    def log_level= (level)
      app.climax_send_event(:set_log_level, level)
    end

    def start_debugger
      app.climax_send_event(:start_remote_debugger)
    end

    def stop
      app.climax_send_event(:quit)
    end
    
    def set_delay(delay)
      delay = nil if delay == 0
      app.climax_send_event(:set_delay, delay)
    end
    
    def pause
      app.climax_send_event(:pause)
    end
    
    def resume
      app.climax_send_event(:resume)
    end
    
    def stats
      stats = app.stats
      sec_per_run = (Time.now - stats[:run_start])/stats[:iterations]
      stats.merge({:seconds_per_iteration => sec_per_run})
    end
    
    def paused?
      app.paused?
    end

  end

  class ControlDRb
    def initialize(app, port, hostname)
      @port = port
      @uri = "druby://#{hostname}:#{@port}"
      server = ControlServer.new(app)
      DRb.start_service(@uri, server)
    end

    def port
      @port
    end

    def uri
      @uri
    end

  end

end
