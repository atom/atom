require 'timeout'

ATOM_SRC = File.dirname(__FILE__)
BUILD_DIR = 'atom-build'

desc "Create xcode project from gpy file"
task "create-project" do
  `rm -rf atom.xcodeproj`
  `python tools/gyp/gyp --depth=. atom.gyp`
end

task :bootstrap do
  `script/bootstrap`
end

desc "Build Atom via `xcodebuild`"
task :build => ["create-project", "bootstrap"] do
  command = "xcodebuild -target Atom configuration=Release SYMROOT=#{BUILD_DIR}"
  output = `#{command}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Clean build Atom via `xcodebuild`"
task :clean do
  output = `xcodebuild clean`
end

desc "Run Atom"
task :run, [:atom_arg] => :build do |name, args|
  if path = application_path()
    cmd = "#{path}/Contents/MacOS/Atom #{args[:atom_arg]} 2> /dev/null"
    puts cmd
    exitstatus = system(cmd)
    exit(exitstatus)
  else
    exit(1)
  end
end

desc "Run the specs"
task :test => :clean do
  Rake::Task["run"].invoke("--test")
end

desc "Run the benchmarks"
task :benchmark do
  Rake::Task["run"].invoke("--benchmark")
end

desc "Creates symlink from `application_path() to /Applications/Atom and creates a CLI at /usr/local/bin/atom"
task :install => :build do
  if path = application_path()
    dest =  File.join("/Applications", File.basename(path))
    rm_rf dest
    cp_r path, File.expand_path(dest)

    usr_bin = "/opt/github/bin"
    if Dir.exists?(usr_bin)
      cli_path = "#{usr_bin}/atom"
      `echo '#!/bin/sh\nopen #{dest} -n --args --resource-path="#{ATOM_SRC}" --executed-from="$(pwd)" $@' > #{cli_path} && chmod 755 #{cli_path}`
    else
      stderr.puts "ERROR: `The Setup` is required to run the atom cli tool"
    end

    rm_rf "#{ENV['HOME']}/.atom"
    ln_sf "#{File.dirname(__FILE__)}/.atom", "#{ENV['HOME']}/.atom"
  else
    exit 1
  end
end

desc "Remove any 'fit' or 'fdescribe' focus directives from the specs"
task :nof do
  system %{find . -name *spec.coffee | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
end

def application_path
  applications = FileList["#{BUILD_DIR}/**/Atom.app"]
  if applications.size == 0
    $stderr.puts "No Atom application found in directory `#{BUILD_DIR}`"
  elsif applications.size > 1
    $stderr.puts "Multiple Atom applications found \n\t" + applications.join("\n\t")
  else
    return applications.first
  end

  return nil
end
