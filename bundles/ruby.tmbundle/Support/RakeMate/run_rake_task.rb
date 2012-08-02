#!/usr/bin/env ruby -w

require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"

class RakeTaskRunner
  def initialize
    @mode = :line_by_line
  end
  
  def run(task = nil, *options, &block)
    build_rake_command(task, *options)
    
    open(@command) do |rake_task|
      if block.nil?
        rake_task.read
      else
        loop do
          break if rake_task.eof?
          new_content = @mode == :char_by_char ? rake_task.getc.chr :
                                                 rake_task.gets
          @mode       = block.arity == 2       ? block[new_content, @mode] :
                                                 block[new_content]
        end
      end
    end
  end
  
  private
  
  def build_rake_command(task, *options)
    @command =  "|"
    @command << ENV["TM_RAKE"] || "rake"
    @command << " " << e_sh(task) unless task.nil?
    unless options.empty?
      @command << " " << options.map { |arg| e_sh(arg) }.join(" ")
    end
    @command << " 2>&1"
  end
end

def run_rake_task(*args, &block)
  RakeTaskRunner.new.run(*args, &block)
end

def fetch_rake_tasks(*args, &block)
  RakeTaskRunner.new.run("--tasks", *args, &block)
end
