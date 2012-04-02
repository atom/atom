require 'fileutils'

$ATOM_ARGS = []

ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"
BUILD_DIR = '/tmp/atom-build'

desc "Build Atom via `xcodebuild`"
task :build => :"verify-prerequisites" do
  output = `xcodebuild -configuration Release SYMROOT=#{BUILD_DIR}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
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
task :test do
  $ATOM_ARGS.push "--test", "--headless"
  Rake::Task["run"].invoke
end

desc "Run the benchmarks"
task :benchmark do
  $ATOM_ARGS.push "--benchmark", "--headless"
  Rake::Task["run"].invoke
end

desc "Compile CoffeeScripts"
task :"compile-coffeescripts" => :"verify-prerequisites" do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH'].to_s

  dest = File.join(built_dir, contents_dir, "Resources")

  %w(index.html src static vendor spec benchmark).each do |dir|
    rm_rf File.join(dest, dir)
    cp_r dir, File.join(dest, dir)
  end

  puts contents_dir
  sh "coffee -c #{dest}/src #{dest}/vendor #{dest}/spec"
end

desc "Change webkit frameworks to use @rpath as install name"
task :"webkit-fix" do
  for framework in FileList["frameworks/*.framework"]
    name = framework[/\/([^.]+)/, 1]
    executable = framework + "/" + name

    `install_name_tool -id @rpath/#{name}.framework/Versions/A/#{name} #{executable}`

    libs = `otool -L #{executable}`
    for name in ["JavaScriptCore", "WebKit", "WebCore"]
      _, path, suffix = *libs.match(/\t(\S+(#{name}.framework\S+))/i)
      `install_name_tool -change #{path} @rpath/../Frameworks/#{suffix} #{executable}` if path
    end
  end
end

desc "Remove any 'fit' or 'fdescribe' focus directives from the specs"
task :nof do
  system %{find . -name *spec.coffee | xargs sed -E -i "" "s/f(it|describe) +(['\\"])/\\1 \\2/g"}
end

task :"verify-prerequisites" do
  `hash coffee`
  if not $?.success?
    abort "error: coffee is required but it's not installed - " +
          "http://coffeescript.org/ - (try `npm i -g coffee-script`)"
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