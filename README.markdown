Introduction
============

Climax is a Ruby gem designed to speed-up the development of command line applications.  It provides
a number of features that nearly all long-running cli application need such as logging, running as a
daemon, processing command line arguments, and something else unexpected.  When your application
uses climax, a control DRb runs with your application, allowing you to manipulate your application
as it runs in the background.  For instance, if your application is running, you can remotely debug
the application at any time.  This is great for long-running processes in production.  Something
strange going on that you'd like to investigate?  Use the control drb to change the log level from
"info" to "debug" to get more info.  Still not sure what's happening?  Attach a debugger to the running process.

You get all of these features for free when your application uses climax.

Installation
============

To install climax simply install the climax gem: `gem install climax` or alternatively place `gem
"climax"` in your application's Gemfile and run bundler.

Getting Started
===============

It's easy to get started.  Just include the `Climax::Application` module into your application
class:

    require 'climax'

    class MyApplication
      include Climax::Application

      def main
        log.info "Hello World"
        return 0
      end
    end

    MyApplication.new(ARGV).run()

The above example is about as simple as you can get.  Here we define an application and give it a
`main` method.  The `main` method will be called REPEATEDLY until it returns a value other than nil.
In the example above `main` will only be called once because it returns `0`.

If you save the above example in a file and run it with `--help` you will get a list of default
command line options provided by climax:

    Usage: my_application [options]
        -d, --daemon            Fork application and run in background
            --log_level         Set to debug, info, warn, error, or fatal.  Default: info.
            --log_file          File to log output to.  By default logs to stdout.
            --control_port      Override the port for the control DRb to listen on.  Default is 7249
        -h, --help              Display this help message.

As you can see climax by default provides some options free of charge.  If you would like to modify
how climax behaves, such as by adding more command line options or maybe removing the option to fork
your application, you can provide these configurations by defining a method in your application
class named `configure`.  The `configure` method is called by climax before it parses command line
options, before it sets up logging, basically before it does anything.  This means that you cannot
use climax facilities such as logging in this method because climax has not yet bootstrapped.

After the `configure` method is run climax bootstraps the environment for your application.  It
parses the arguments passed from the command line, it sets up logging, forks your application if
asked to, and starts the control drb unless your application requests otherwise.

The climax framework then runs your application as follows:

 * Calls the `pre_main` method of your application class if it exists.  This is an excellent place
   to put code that should run once before your `main` method.

 * Calls the `main` method of your application class.  If this method does not exist climax will
   raise an exception.  The `main` method will be called **repeatedly** until it returns a value
   other than nil.  If the `main` method returns an integer then your application will exit with
   that integer as the status code.  If the `main` method returns a string then your application
   will abort with that string as the message.

 * Calls the `post_main` method of your application class if it exists.  This is a good place to put
   code that should run once when your application is exiting.

Here is a slightly larger example that shows more of climax's features:

    require 'climax'
    
    class MyApplication
      include Climax::Application
    
      def configure
        options do
          on 'v', 'verbose', 'More verbose'
        end
      end
      
      def pre_main
        log.debug "App has initialized and is about to run."
      end
      
      def main
        puts "Hello World!"
        sleep 3
        return nil
      end

      def post_main
        log.debug "App has finished running and is about to exit."
      end
    end

The above example is a simple application that adds an extra command line option `--verbose` in the
`configure` method.  The `pre_main` method is simple and just writes a debug log statement.  As you
can see logging has been setup at this point.  Then the `main` method is called.  Because the `main`
method in this example always returns nil, this application will run forever until it is stopped
externally (`Ctrl-C`, `kill -9`, or using the Control DRb).  Using `Ctrl-C` and `kill -9` will
immediately halt execution of the application and `post_main` will never be called.  However if the
Control DRb is used then the application will exit in an orderly fashion and the `post_main` method
will be called.  Notice that for free you can fork this application, change the log level with the
`--log-level` option, write the logs to a file using the `--log-file` option, and you can start a
debugger at any time while this application is running using the Control DRb.  The Control DRb has a
lot of power.  We'll talk about it more below.

Climax Event Queue
==================

An important concept to understand is that climax handles events that come in from the Control DRb.
DRb's by necessity run in a separate thread.  However, climax makes absolutely no assumptions about
the thread-safeness of your application.  **You do not need to write thread safe applications.**
Climax is written in such a way that it simply places events into a thread safe queue.  Every time
your `main` method completes, any existing events in the queue are processed.  Your `main` method is
then called again.  This process goes on until the `main` method returns a value other than nil or
an `:exit` or `:quit` event is placed in the event queue.

Your application can send events to the climax event queue with the `send_event` method.  You must
pass `send_event` the event type (e.g., `:exit` or `:start_remote_debugger`) and you may also
optionally pass a payload (i.e., extra data) as a second parameter.

For example, if you wish for your application to exit in an orderly fashion **after** the current
iteration of `main` has had a chance to finish, you can accomplish this by placing an `:exit` event
onto the event queue and letting your `main` method finish its work.  When your `main` method is
finished the events on the queue will be processed by climax.  When climax reads the `:exit` event
off of the queue it will call your `post_main` method and perform other cleanup tasks and then exit.

    require 'climax'

    class MyApplication
      include Climax::Application
      
      def main
        send_event(:exit) if about_to_meet_work_quota?
        work = get_some_work
        do_work(work)
        return nil
      end

      # ...

    end

A consequence of this is that when you issue commands to the Control DRb, your command will not be
processed until the current iteration of `main` has had a chance to complete.  Therefore it is a
good idea to keep each iteration of `main` as short as possible, although this is certainly not a
requirement.  In other words, if you wish to enter the remote debugger for a running process, the
debugger will not begin until the current iteration of `main` has completed.

This is excellent for stopping a long running process without interrupting its work.  By sending an
:exit or :quit event, whether through the Control DRb or from your application itself, your
application will be allowed to finish processing its current unit of work before exiting.

Generating a New Application
============================

To help you get started quickly, you can easily generate a new application using climax by running
the following command:

    climax create <project-name>

Climax will then create a new project for you that is ready to rock and roll.  Here is the file
structure generated for a new project named "my_project":

    my_project/
      Gemfile
      LICENSE.txt
      README.md
      Rakefile
      bin/
        my_project*
      features/
        step_definitions/
        support/
          io.rb
          env.rb
      lib/
        my_project.rb
        my_project/
          version.rb
      my_project.gemspec
      pkg

Your new application has the boilerplate code necessary to start running your application immediately:

    cd my_project
    ./bin/my_project --help
    Usage: my_project [options]
        -d, --daemon            Fork application and run in background
            --log_level         Set to debug, info, warn, error, or fatal.  Default: info.
            --log_file          File to log output to.  By default logs to stdout.
            --control_port      Override the port for the control DRb to listen on.  Default is 7249
        -h, --help              Display this help message.

Running the application will simply print `"Hello World"` until you hit `Ctrl-C`.

The three files you will want to modify are `README.md` (with info about your application),
`<project-name>.gemspec` and `lib/<project-name>.rb`.

You can bundle your application with `gem bundle *.gemspec`.
