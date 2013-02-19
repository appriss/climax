$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
require 'climax'

module HelloWorld
  class Application
    include Climax::Application

    def post_initialize
      options do
        on 'v', 'verbose', 'More verbose'
      end
    end

    def main
      puts "Hello World!"
      sleep 3
    end
  end
end
