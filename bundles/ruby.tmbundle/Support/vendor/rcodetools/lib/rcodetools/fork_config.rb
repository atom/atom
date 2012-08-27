
module Rcodetools

module Fork
  PORT = 9085
  # Contains $PWD of rct-fork server. Exists only while running.
  PWD_FILE = File.expand_path "~/.rct-fork.pwd"

  def self.chdir_fork_directory
    if run?
      Dir.chdir File.read(PWD_FILE)
    else
      raise "rct-fork is not running."
    end
  end

  def self.write_pwd
    open(PWD_FILE, "w"){|f| f.print Dir.pwd }
  end

  def self.run?
    File.file? PWD_FILE
  end
end
  
end
