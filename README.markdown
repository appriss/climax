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
externally (`Ctrl-C`, `kill`, or using the Control DRb).  Using `Ctrl-C` and `kill -INT` (i.e.,
sending an Interrupt signal) will cause the application to exit gracefully. The current iteration of
`main` will finish and then `post_main` will be run.  You can send another Interrupt signal, for
example by hitting `Ctrl-C` twice, to exit the application immediately.  Likewise if the Control DRb
is used then the application will exit in an orderly fashion and the `post_main` method will be
called.  Notice that for free you can fork this application, change the log level with the
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

Your application can send events to the climax event queue with the `climax_send_event` method.  You
must pass `climax_send_event` the event type (e.g., `:exit` or `:start_remote_debugger`) and you may
also optionally pass a payload (i.e., extra data) as a second parameter.

For example, if you wish for your application to exit in an orderly fashion **after** the current
iteration of `main` has had a chance to finish, you can accomplish this by placing an `:exit` event
onto the event queue and letting your `main` method finish its work.  When your `main` method is
finished the events on the queue will be processed by climax.  When climax reads the `:exit` event
off of the queue it will call your `post_main` method and perform other cleanup tasks and then exit.

    require 'climax'

    class MyApplication
      include Climax::Application
      
      def main
        climax_send_event(:exit) if about_to_meet_work_quota?
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

This is exactly how graceful exiting is accomplished with climax.  When you send an Interrupt signal
(via `Ctrl-C` or by sending a `kill -INT` to your application), climax intercepts this signal and
places a `:exit` event onto the event queue.  If climax intercepts a second Interrupt signal it will
halt execution immediately.

This is excellent for stopping a long running process without interrupting its work.  By sending an
:exit or :quit event, whether through the Control DRb, or by sending an Interrupt signal, or from
your application itself, your application will be allowed to finish processing its current unit of
work before exiting.

For your convenience there is also a 'climax_has_event?' method that returns true only if there are
events waiting on the event queue.  Your application can use this to determine if `main` should give
up control temporarily to allow climax to handle events on the queue.

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

Control DRb
===========

The Control DRb provides a way to interact with your running application.  In future releases expect
new functionality to be added to the Control DRb and expect new ways of interacting with your long
running jobs.

You control your application with `climax control`.  Simply pass `climax control` the name of the
command you wish to send to your application and any optional arguments.  If your application is
using a different port than the default (7249) you can tell climax which port to connect on with the
`-p <port>` option:

    climax control -p 1234 start_debugger

Starting the Debugger
---------------------

To attach to your running application with a debugger, simply make sure your application is running
and then execute:

    climax control start_debugger

When you are finished type `quit` to exit the debugger and resume your application.  

Extending the Control DRb with Custom Functionality
---------------------------------------------------

Extending the Control DRb is a key aspect of climax.  For instance it is a common idiom for web
applications to delegate difficult tasks to background jobs.  Let's take a common scenario and see
how we might implement this scenario with climax.

In this example there is a web application that allows users to upload images.  The image is stored
in a temporary directory by the web application and then a request is sent to a background job
asking it to process the image and store it in a more permanent location.  Let's say the web
application simply wants to send the command `process_image` and pass as an argument the path of the
image that was uploaded.

Let's see how we can extend the Control DRb with a `process_image` method.  We'll also see a possible
workflow for how the background job might tackle its work.

    require 'climax'
    require 'fileutils'
    
    module Climax
      class ControlServer
        def process_image (path)
          app.climax_send_event(:process_image, path)
        end
      end
    end
    
    class ImageProcessor
      include Climax::Application
    
      def configure
        options do
          on 't', 'target-directory=', 'Destination directory to save processed images to.', :default => '/var/saved/images'
        end
      end
    
      def pre_main
        FileUtils.mkdir_p(opts[:'target-directory'])
        @processor_queue = []
      end
    
      def main
        if @processor_queue.empty?
          sleep 0.5
          return nil
        end
    
        image_path = @processor_queue.pop
        log.info "Processing image #{image_path}"
        do_work(image_path)
        return nil
      end
    
      def process_image (path)
        @processor_queue.push(path)
      end
    
      def do_work(path)
        # process image at path
        # save to target directory
      end
    end

Adding your own commands to the Control DRb couldn't be easier.  Simply extend the
`Climax::ControlServer` class with your own methods that push events onto the climax event queue.
When climax processes the event it will call a method in your application instance with the same
name as the event.  In the example above we send a `:process_image` event with an argument.  When
climax processes this event it will attempt to call a `process_image` method in the application
instance, passing along any arguments.

In this case we simply add the work to a simple queue and allow `main` to process the jobs from the
queue.

Notice that when you are extending `Climax::ControlServer` you have access to your application
instance via the `app` method.  From here you can call any publicly available methods on your
application instance.  *But be careful*.  The DRb is running in a separate thread.  This is why we
simply send events!  It is always best to only send events from your custom ControlServer methods.
Doing so allows you to never need worry about making your application thread-safe.  If you're a
cowboy and decide to call various public methods on your app instance directly from your custom
`ControlServer` methods you may end up with some strange results.  So unless you are familiar with
thread-safe applications it is suggested that you only place events onto the queue from your custom
`ControlServer` methods.

Now the web application can simply connect to your application's DRb and call the `process_image`
method, passing it an image path.

Something interesting about this is that non-ruby applications can also easily tell our image
processor to process images.

For instance you can send commands to your application using the `climax` CLI interface:

    climax control process_image /tmp/uploaded-images/tmp-d8ej2.jpg

This means any application, even just simple shell scripts, can easily send commands to our
background job.

Of course it is best to give each of your climax applications a unique Control DRb port.  You can
then specify which port to send commands to with the `-p` option to `climax control`:

    climax control -p $IMAGE_PROCESSOR_PORT process_image /tmp/uploaded-images/tmp-d8ej2.jpg
