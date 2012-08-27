## Rcodetools version of ruby_fork
# 
# Based on ruby_fork.rb by Ryan Davis, Eric Hodel, Zen Spider Software
#
#  (The MIT License)
#
#  Copyright (c) 2006 Ryan Davis, Eric Hodel, Zen Spider Software <support@zenspider.com>
#                2007 rubikitch <rubikitch@ruby-lang.org>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'optparse'
require 'socket'
require 'rcodetools/fork_config'

module Rcodetools
module Fork

  USAGE_HELP = <<XXX

rct-fork and rct-fork-client (we) are originally ruby_fork/ruby_fork_client in ZenTest by Zen Spider Software and are slightly modified for rcodetools.
Completion or document browsing in a script with heavy libraries such as Rails takes a significant latency.
We eliminate constant overhead of loading heavy libraries.

rct-fork loads libraries you want to pre-load and opens up a server socket and waits for connection. When a connection comes in rct-fork forks to make a copy of the environment. rct-fork loads rubygems at startup.

rct-fork-client connects to the rct-fork server and runs script in server's environment.

xmpfilter/rct-complete/rct-doc can auto-detect rct-fork process with --fork option.
This means that once you start up rct-fork, you do not have to start up rct-fork-client manually.

demo/fork-demo.sh shows rct-fork example.

!!WARNING!!
We are only meant to run xmpfilter/rct-complete/rct-doc!
If you want to run other programs, use original ruby_fork/ruby_fork_client.
XXX
  # '

  DEFAULT_SETTINGS = {
    :requires => [],
    :code => [],
    :extra_paths => [],
    :port => PORT,
  }

  def self.add_env_args(opts, settings)
    opts.separator ''
    opts.separator 'Process environment options:'

    opts.separator ''
    opts.on('-e CODE', 'Execute CODE in parent process.',
            'May be specified multiple times.') do |code|
      settings[:code] << code
    end

    opts.separator ''
    opts.on('-I DIRECTORY', 'Adds DIRECTORY to $LOAD_PATH.',
            'May be specified multiple times.') do |dir|
      settings[:extra_paths] << dir
    end

    opts.separator ''
    opts.on('-r LIBRARY', 'Require LIBRARY in the parent process.',
            'May be specified multiple times.') do |lib|
      settings[:requires] << lib
    end
  end

  def self.parse_client_args(args)
    settings = Marshal.load Marshal.dump(DEFAULT_SETTINGS)

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]\n#{USAGE_HELP}"

      opts.separator ''
      opts.on('-p', '--port PORT',
              'Listen for connections on PORT.',
              "Default: #{settings[:port]}") do |port|
        settings[:port] = port.to_i
              end

      opts.separator ''
      opts.on('-h', '--help', 'You\'re looking at it.') do
        $stderr.puts opts
        exit 1
      end

      add_env_args opts, settings
    end

    opts.parse! args

    return settings
  end

  def self.parse_server_args(args)
    settings = Marshal.load Marshal.dump(DEFAULT_SETTINGS)

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]\n#{USAGE_HELP}"

      opts.separator ''
      opts.on('-p', '--port PORT',
              'Listen for connections on PORT.',
              "Default: #{settings[:port]}") do |port|
        settings[:port] = port.to_i
      end

      opts.separator ''
      opts.on('-h', '--help', 'You\'re looking at it.') do
        $stderr.puts opts
        exit 1
      end

      add_env_args opts, settings
    end

    opts.parse! args

    return settings
  end

  def self.start_client(args = ARGV)
    trap 'INT' do exit 1 end # Exit gracefully

    settings = parse_client_args args

    args = Marshal.dump [settings, ARGV]

    socket = TCPSocket.new 'localhost', settings[:port]

    socket.puts args.length
    socket.write args
    socket.close_write
  end

  def self.start_server(args = ARGV)
    begin
      require 'rubygems'
    rescue LoadError
    end
    write_pwd
    settings = parse_server_args args
    setup_environment settings

    server = TCPServer.new 'localhost', settings[:port]

    $stderr.puts "#{$0} Running as PID #{$$} on #{settings[:port]}"

    loop do
      Thread.new server.accept do |socket|
        begin
          args_length = socket.gets.to_i
          args = socket.read args_length
          settings, argv = Marshal.load args
          fork do
            ARGV.replace argv
            setup_environment settings
            socket.close
          end
          socket.close # close my copy.
        rescue => e
          socket.close if socket
        end
      end
    end
  rescue Interrupt, SystemExit
    File.unlink PWD_FILE
  rescue Exception => e
    File.unlink PWD_FILE
    puts "Failed to catch #{e.class}:#{e.message}"
    puts "\t#{e.backtrace.join "\n\t"}"
  end

  def self.setup_environment(settings)
    settings[:extra_paths].map! { |dir| dir.split ':' }
    settings[:extra_paths].flatten!
    settings[:extra_paths].each { |dir| $:.unshift dir }

    begin
      settings[:requires].each { |file| require file }
      settings[:code].each { |code| eval code, TOPLEVEL_BINDING }
    rescue Exception
      $@.reject! {|s| s =~ %r!rcodetools/fork\.rb!}
      raise
    end
  end

end

end

