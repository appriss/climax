require 'drb/drb'

module Climax
  class ControlServer
    def initialize(app)
      @app = app
    end

    def log_level
      @app.log_level
    end

    def log_level= (level)
      @app.send_event(:set_log_level, level)
    end

    def start_debugger
      @app.send_event(:start_remote_debugger)
    end
  end

  class ControlDRb
    def initialize(app, port)
      @port = port
      server = ControlServer.new(app)
      DRb.start_service(uri, server)
    end

    def port
      @port
    end

    def uri
      "druby://localhost:#{port}"
    end

  end

end
