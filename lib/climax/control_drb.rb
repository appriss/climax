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

  end

  class ControlDRb
    def initialize(app, port, hostname, safe=(hostname != 'localhost'))
      @port = port
      @uri = "druby://#{hostname}:#{@port}"
      server = ControlServer.new(app)
      #
      if safe
        $SAFE = 1
      end
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
