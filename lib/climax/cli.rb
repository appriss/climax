require 'slop'

require 'climax/commands/create'
require 'climax/commands/control'

module Climax
  module CLI
    class Application

      def initialize (args)
        @args = args.dup
        @opts = Slop.parse(:strict => true, :help => true) do
          command 'create' do
            run do |options, args|
              Climax::CLI::Command::Create.new(options, args).run
            end
          end

          command 'control' do
            on 'p', 'port=', 'Port of control drb to connect to.  Default: 7249', :default => 7249, :as => :int
            run do |options, args|
              Climax::CLI::Command::Control.new(options, args).run
            end
          end
        end
      end

      def opts
        @opts
      end

    end
  end
end
