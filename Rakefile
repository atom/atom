ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"

desc "Build the shit."
task :build do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH'].to_s

  dest = File.join(built_dir, contents_dir, "Resources")

  %w(index.html src docs static extensions vendor spec).each do |dir|
    rm_rf File.join(dest, dir)
    cp_r dir, File.join(dest, dir)
  end

  `hash coffee`
  if not $?.success?
    abort "error: coffee is required but it's not installed - " +
          "http://coffeescript.org/ - (try `npm i -g coffee-script`)"
  end

  puts contents_dir
  sh "coffee -c #{dest}/src #{dest}/vendor #{dest}/extensions #{dest}/spec"
end

desc "Install the app in /Applications"
task :install do
  rm_rf "/Applications/Atomicity.app"
  cp_r "Cocoa/build/Debug/Atomicity.app /Applications"
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

