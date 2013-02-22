require 'drb'
require 'pry-remote'

module Climax
  module CLI
    module Command
      class Control

        def initialize (options, args)
          @opts = options.dup
          @args = args.dup
        end

        def run
          args = @args.dup
          DRb.start_service
          server = DRbObject.new_with_uri("druby://localhost:#{port}")
          command = args.shift
          server.send(command, *args)

          if command == "start_debugger"
            success = nil
            begin
              PryRemote::CLI.new.run
              success = true
            rescue
            end while success.nil?
          end
        end

        def opts
          @opts
        end

        def port
          @port ||= @opts[:port]
        end
      end
    end
  end
end
