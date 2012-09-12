require 'timeout'

$ATOM_ARGS = []

ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"
BUILD_DIR = 'atom-build'

desc "Create xcode project from gpy file"
task "create-project" do
  `rm -rf atom.xcodeproj`
  `python tools/gyp/gyp --depth=. atom.gyp`
  # `killall -c Xcode -9`
  # `open atom.xcodeproj` # In order for the xcodebuild to know about the schemes, the project needs to have been opened once. This is xcode bullshit and is a bug on Apple's end (No radar has been file because I have no faith in radar's)
  Timeout::timeout(10) do
    sleep 0 while `xcodebuild -list` =~ /This project contains no schemes./ # Give xcode some time to open
  end
end

desc "Build Atom via `xcodebuild`"
task :build => ["create-project", "verify-prerequisites"] do
  command = "xcodebuild -target Atom -configuration Debug -scheme Atom" # -scheme is required, otherwise xcodebuild creates a binary that won't run on Corey's Air. He recieves the error "Check failed: !loaded_locale.empty(). Locale could not be found for en-US"
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
      `echo '#!/bin/sh\nopen #{path.strip} --args $@' > #{cli_path} && chmod 755 #{cli_path}`
      # `echo '#!/bin/sh\n#{path}/Contents/MacOS/Atom $@' > #{cli_path} && chmod 755 #{cli_path}`
    else
      stderr.puts "ERROR: Did not add cli tool for `atom` because /usr/local/bin does not exist"
    end
  else
    exit(1)
  end
end

desc "Run Atom"
task :run => :build do
  if path = application_path()
    exitstatus = system "open #{path} #{$ATOM_ARGS.join(' ')} 2> /dev/null"
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

desc "Remove any 'fit' or 'fdescribe' focus directives from the specs"
task :nof do
  system %{find . -name *spec.coffee | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
end

task "copy-files-to-bundle" => ["verify-prerequisites", "create-xcodebuild-info"] do
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

    `coffee -c '#{dest_path.gsub(" ", "\\ ")}'`
  end
end

task "create-xcodebuild-info" do
  `echo $TARGET_BUILD_DIR/$FULL_PRODUCT_NAME > .xcodebuild-info`
end

task :"verify-prerequisites" do
  `hash coffee`
  if not $?.success?
    abort "error: coffee is required but it's not installed - " +
          "http://coffeescript.org/ - (try `npm i -g coffee-script`)"
  end
end

def application_path
  if not path = File.open('.xcodebuild-info').read()
    $stderr.puts "Error: No .xcodebuild-info file found. This file is created when the `build` raketask is run"
  end

  return path.strip()
end
