$ATOM_ARGS = []

ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"
BUILD_DIR = '/tmp/atom-build'

desc "Build Atom via `xcodebuild`"
task :build do
  output = `xcodebuild SYMROOT=#{BUILD_DIR}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Run Atom"
task :run => :build do
  applications = FileList["#{BUILD_DIR}/**/*.app"]
  if applications.size == 0
    $stderr.puts "No Atom application found in directory `#{BUILD_DIR}`"
  elsif applications.size > 1
    $stderr.puts "Multiple Atom applications found \n\t" + applications.join("\n\t")
  else
    app_path = "#{applications.first}/Contents/MacOS/Atom"
    if File.exists?(app_path)
      exitstatus = system "#{applications.first}/Contents/MacOS/Atom #{$ATOM_ARGS.join(' ')} 2> /dev/null"
      exit(exitstatus)
    else
      $stderr.puts "Executable `#{app_path}` not found."
    end
  end
end

desc "Run the specs"
task :test do
  $ATOM_ARGS.push "--test", "--headless"
  Rake::Task["run"].invoke
end

desc "Run the benchmarks"
task :benchmark do
  $ATOM_ARGS.append "--benchmark", "--headless"
  Rake::Task["run"].invoke
end

desc "Compile CoffeeScripts"
task :"compile-coffeescripts" do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH'].to_s

  dest = File.join(built_dir, contents_dir, "Resources")

  %w(index.html src static vendor spec).each do |dir|
    rm_rf File.join(dest, dir)
    cp_r dir, File.join(dest, dir)
  end

  `hash coffee`
  if not $?.success?
    abort "error: coffee is required but it's not installed - " +
          "http://coffeescript.org/ - (try `npm i -g coffee-script`)"
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

