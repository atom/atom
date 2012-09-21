require 'timeout'

ATOM_SRC_PATH = File.dirname(__FILE__)
BUILD_DIR = 'atom-build'

desc "Create xcode project from gpy file"
task "create-project" do
  `rm -rf atom.xcodeproj`
  `python tools/gyp/gyp --depth=. atom.gyp`
end

desc "Build Atom via `xcodebuild`"
task :build => "create-project" do
  `script/bootstrap`

  command = "xcodebuild -target Atom configuration=Release SYMROOT=#{BUILD_DIR}"
  output = `#{command}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Creates symlink from `application_path() to /Applications/Atom and creates `atom` cli app"
task :install => :build do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest =  "/Applications/#{File.basename(path)}"
  `rm -rf #{dest}`
  `cp -r #{path} #{File.expand_path(dest)}`

  # Install cli atom
  default_usr_bin = "/opt/github/bin"
  print "Where do you want the cli binary insalled (#{default_usr_bin}): "
  usr_bin = $stdin.gets.strip
  usr_bin = default_usr_bin if usr_bin.empty?

  if Dir.exists?(usr_bin)
    cli_path = "#{usr_bin}/atom"
    `echo '#!/bin/sh\nopen #{dest} -n --args --resource-path="#{ATOM_SRC_PATH}" --executed-from="$(pwd)" $@' > #{cli_path} && chmod 755 #{cli_path}`
  else
    $stderr.puts "ERROR: Failed to install atom cli tool at '#{usr_bin}'"
    exit 1
  end

  # Create ~/.atom
  dot_atom_path = ENV['HOME'] + "/.atom"
  dot_atom_template_path = ATOM_SRC_PATH + "/.atom"
  replace_dot_atom = false
  if File.exists?(dot_atom_path) && !File.symlink?("#{dot_atom_path}/default-config.coffee")
    print "I am going to replace '#{dot_atom_path}' with the default .atom directory (y/n): "
    replace_dot_atom = true if STDIN.gets.strip =~ /^y/i
  end

  if replace_dot_atom
    `rm -rf "#{dot_atom_path}"`
    `mkdir "#{dot_atom_path}"`
    `cp "#{dot_atom_template_path}/atom.coffee" "#{dot_atom_path}"`

    for path in Dir.entries(dot_atom_template_path)
      next if ["..", ".", "atom.coffee"].include? path
      `ln -s "#{dot_atom_template_path}/#{path}" "#{dot_atom_path}"`
    end
  end

  puts "\033[32mType `atom` to start Atom! In Atom press `cmd-,` to edit your `.atom` directory\033[0m"
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
