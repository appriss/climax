require 'fileutils'
require 'erb'

module Climax
  module CLI
    module Command
      class Create

        def initialize (options, args)
          @opts = options.dup
          @args = args.dup
        end

        def run
          raise "Too many arguments.  Just pass name of new climax application" if args.length > 1
          raise "Not enough arguments.  Please pass name of new climax application" if args.length < 1
          @full_path = args[0]
          @name = File.basename(@full_path)
          @dir = File.dirname(@full_path)

          create_directory_structure @name, @dir
        end

        def in_directory (dir, &block)
          cwd = FileUtils.pwd
          FileUtils.mkpath(dir)
          FileUtils.cd(dir)
          begin
            yield
          ensure
            FileUtils.cd(cwd)
          end
        end

        def create_directory_structure (name, dir)
          in_directory(dir) do
            # Create standard bundler gem layout
            %x[bundle gem #{name}]
            # Add a couple extra directories
            FileUtils.mkpath(["#{name}/bin", "#{name}/features", "#{name}/pkg"])

            # Get bundler generated module path
            gemspec = File.read("#{name}/#{name}.gemspec")
            module_string = /gem.version\s+=\s+(.*)::VERSION/.match(gemspec)[1]
            module_path = module_string.split("::")

            template_dir = File.join(File.dirname(__FILE__), "..", "..", "..", "templates")

            File.open("#{name}/bin/#{name}", "w") do |file|
              file.write(ERB.new(File.read(File.join(template_dir, "application_wrapper.erb")), 0, '<>').result(binding))
            end

            FileUtils.chmod "+x", "#{name}/bin/#{name}"

            File.open("#{name}/lib/#{name}.rb", "w") do |file|
              file.write(ERB.new(File.read(File.join(template_dir, "application.rb.erb")), 0, '<>').result(binding))
            end

            gemspec.gsub!(/^end$/, "  gem.add_development_dependency \"cucumber\"\n  gem.add_runtime_dependency \"climax\"\nend")
            File.open("#{name}/#{name}.gemspec", "w") do |file|
              file.write(gemspec)
            end

          end
        end

        def opts
          @opts
        end

        def args
          @args
        end
      end
    end
  end
end