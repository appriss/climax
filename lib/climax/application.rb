require "pry"
require "slop"
require "logger"
require "pry-remote"
require "climax/version"
require "climax/control_drb"

module Climax
  module Application

    def initialize(args=[])
      @args = args.dup
      options do
        on :d, :daemon,    "Fork application and run in background"
        on :log_level=,    "Set to debug, info, warn, error, or fatal.  Default: info.", :default => "info"
        on :log_file=,     "File to log output to.  By default logs to stdout.", :default => nil
        on :control_port=, "Override the port for the control DRb to listen on.  Default is 7249", :as => :int, :default => 7249
      end
      configure
      _parse_options
    end

    def _pre_main
      if daemonize?
        exit 0 if !Process.fork.nil?
        log.debug "Running in background (#{$$})"
      end

      log.debug "Starting Control DRb on port #{control_port}"
      @control_drb = Climax::ControlDRb.new(self, control_port)
    end

    def _post_main
      log.debug "Stopping Control DRb"
      @control_drb.stop_service
    end

    def _parse_options
      slop.parse!
      @opts = slop
      exit 0 if opts.help?
    rescue => e
      abort("#{e.message}\n#{slop.to_s}")
    end

    def daemonize?
      @daemonize = opts[:daemon]
    end

    def log
      if @log.nil?
        @log = Logger.new(log_file || $stdout, "daily")
        @log.level = log_level
        if log_file
          @log.formatter = proc do |severity, datetime, progname, msg|
            datetime = datetime.strftime("%Y-%m-%d %H:%M:%S")
            "[#{datetime}] #{$$} #{severity} -- #{msg}\n"
          end
        else
          # Give a more concise format when logging to STDOUT
          @log.formatter = proc do |severity, datetime, progname, msg|
            "#{severity}: #{msg}\n"
          end
        end
      end
      @log
    end

    def control_port
      @control_port ||= opts[:control_port]
    end

    def control_port= (port)
      raise "Cannot set control port to #{port}: ControlDRb is already running!" if @control_drb
      @control_port = port
    end

    def log_file
      @log_file ||= opts[:log_file]
    end

    def log_file= (path)
      if !@log.nil?
        warning = "Changing log path to #{path}!"
        $stderr.write(warning)
        log.warn(warning)
        @log = nil
      end
      @log_file = path
    end

    # Return current log_level
    def log_level
      @log_level ||= string_to_log_level opts[:log_level]
    end

    # Set log level to "debug", "warn", "info", etc. or use Logger::DEBUG, etc.
    def log_level= (level)
      log.level = @log_level = string_to_log_level(level)
      log.warn("Changed log level to #{level}")
    end

    # Example: "debug" => Logger::DEBUG
    def string_to_log_level (string)
      return string if string.is_a? Fixnum
      Logger.const_get(string.upcase)
    end

    # Raw command line arguments passed to application
    def args
      @args
    end

    # Return instance of Slop
    def slop
      @slop ||= Slop.new(:strict => true, :help => true)
    end

    # Method for wrapping calls to on() and banner().  Simply for readability.
    # Example:
    # options do
    #   on 'v', 'verbose', 'More output'
    # end
    def options (&block)
      yield
    end

    # Run the application
    def run
      _pre_main
      pre_main
      @exit_status = _event_loop
      _post_main
      post_main

      exit exit_status if exit_status.is_a? Fixnum
      abort(exit_status.to_s)
    end

    def exit_status
      @exit_status
    end

    # Return current options.  nil until ClimaxApplication::new has finished running
    def opts
      @opts
    end

    # Set a command line option ala Slop
    def on (*args)
      slop.on(*args)
    end

    # Set help banner output ala Slop
    def banner (*args)
      slop.banner(*args)
    end

    def command (cmd, &block)
      slop.command(cmd, block)
    end

    def _event_loop
      while true

        begin
          event = _next_event

          unless event.nil?
            case event.type
            when :set_log_level then log_level = event.payload
            when :stop_control_drb then @control_drb && @control_drb.stop_service
            when :start_remote_debugger then binding.remote_pry
            when :quit, :exit then return 0
            end
          end
        end while !event.nil?

        result = main
        return result if !result.nil?
      end
    end

    def send_event (type, payload=nil)
      _events_mutex.synchronize {
        _events.unshift OpenStruct.new(:type => type, :payload => payload)
      }
    end

    def _events
      @_events ||= []
    end

    def _next_event
      _events_mutex.synchronize {
        _events.pop
      }
    end

    def _events_mutex
      @_events_mutex ||= Mutex.new
    end

    def configure
    end

    def main
      raise "Please implement a main() method for your application."
    end

    def pre_main
    end

    def post_main
    end

  end
end