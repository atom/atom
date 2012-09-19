require 'timeout'

$ATOM_ARGS = []
ENV['PATH'] = "#{ENV['PATH']}:/opt/github/bin/"

COFFEE_PATH = "node_modules/.bin/coffee"
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
  puts command
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
task :run => :build do
  if path = application_path()
    puts path
    exitstatus = system "#{path}/Contents/MacOS/Atom #{$ATOM_ARGS.join(' ')} 2> /dev/null"
    exit(exitstatus)
  else
    exit(1)
  end
end

desc "Run the specs"
task :test => :clean do
  $ATOM_ARGS.push "--test"
  Rake::Task["run"].invoke
end

desc "Run the benchmarks"
task :benchmark do
  $ATOM_ARGS.push "--benchmark"
  Rake::Task["run"].invoke
end

desc "Create the Atom.app for distribution"
task :package => :build do
  if path = application_path()
    rm_rf "pkg"
    mkdir_p "pkg"
    cp_r path, "pkg/"
    `cd pkg && zip -r atom.zip .`
  else
    exit(1)
  end
end

desc "Creates symlink from `application_path() to /Applications/Atom and creates a CLI at /usr/local/bin/atom"
task :install => :build do
  if path = application_path()
    ln_sf File.expand_path(path), "/Applications"
    usr_bin = "/usr/local/bin"
    usr_bin_exists = ENV["PATH"].split(":").include?(usr_bin)
    if usr_bin_exists
      cli_path = "#{usr_bin}/atom"
      `echo '#!/bin/sh\nopen #{path} -n --args "--executed-from=$(pwd)" $@' > #{cli_path} && chmod 755 #{cli_path}`
    else
      stderr.puts "ERROR: Did not add cli tool for `atom` because /usr/local/bin does not exist"
    end

    sh 'say DONE!'
  else
    exit(1)
  end
end

desc "Remove any 'fit' or 'fdescribe' focus directives from the specs"
task :nof do
  system %{find . -name *spec.coffee | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
end

desc "Copy files to bundle and compile CoffeeScripts"
task :"copy-files-to-bundle" do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH']

  dest = File.join(built_dir, contents_dir, "Resources")

  mkdir_p "#{dest}/v8_extensions"
  cp Dir.glob("#{project_dir}/native/v8_extensions/*.js"), "#{dest}/v8_extensions/"

  %w(src static vendor spec benchmark bundles themes).each do |dir|
    dest_path = File.join(dest, dir)
    rm_rf dest_path
    cp_r dir, dest_path

    `#{COFFEE_PATH} -c '#{dest_path.gsub(" ", "\\ ")}'`
  end
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
