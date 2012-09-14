require 'fileutils'

$ATOM_ARGS = []

ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"
BUILD_DIR = 'atom-build'
mkdir_p BUILD_DIR

desc "Create xcode project from gpy file"
task "create-project" do
  sh "rm -rf atom.xcodeproj"
  sh "python tools/gyp/gyp --depth=. atom.gyp"
end

desc "Build Atom via `xcodebuild`"
task :build => "create-project" do
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
  output = `xcodebuild clean SYMROOT=#{BUILD_DIR}`
  rm_rf BUILD_DIR
end

desc "Create the Atom.app for distribution"
task :package => :build do
  if path = application_path()
    FileUtils.rm_rf "pkg"
    FileUtils.mkdir_p "pkg"
    FileUtils.cp_r path, "pkg/"
    `cd pkg && zip -r atom.zip .`
  else
    exit(1)
  end
end

desc "Run Atom"
task :run => :build do
  if path = binary_path()
    exitstatus = system "#{path} #{$ATOM_ARGS.join(' ')} 2> /dev/null"
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

desc "Copy files to bundle and compile CoffeeScripts"
task :"copy-files-to-bundle" do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH']

  dest = File.join(built_dir, contents_dir, "Resources")

  mkdir_p "#{dest}/v8_extensions"
  cp Dir.glob("#{project_dir}/native/v8_extensions/*.js"), "#{dest}/v8_extensions/"

  if resource_path = ENV['RESOURCE_PATH']
    # CoffeeScript can't deal with unescaped whitespace in 'Atom Helper.app' path
    escaped_dest = dest.gsub("Atom Helper.app", "Atom\\ Helper.app")
    sh "vendor/coffee -c -o \"#{escaped_dest}/src/stdlib\" \"#{resource_path}/src/stdlib/require.coffee\""
    cp_r "#{resource_path}/static", dest
  else
    # TODO: Restore this list when we add in all of atoms source
    %w(src static vendor spec benchmark bundles themes).each do |dir|
      dest_path = File.join(dest, dir)
      rm_rf dest_path
      cp_r dir, dest_path
      sh "vendor/coffee -c '#{dest_path}'"
    end
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

def binary_path
  if app_path = application_path()
    binary_path = "#{app_path}/Contents/MacOS/Atom"
    if File.exists?(binary_path)
      return binary_path
    else
      $stderr.puts "Executable `#{app_path}` not found."
    end
  end

  return nil
end
