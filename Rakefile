ENV['PATH'] = "#{ENV['PATH']}:/usr/local/bin/"

desc "Build the shit."
task :build do
  project_dir  = ENV['PROJECT_DIR'] || '.'
  built_dir    = ENV['BUILT_PRODUCTS_DIR'] || '.'
  contents_dir = ENV['CONTENTS_FOLDER_PATH'].to_s

  dest = File.join(built_dir, contents_dir, "Resources")

  %w( src docs static plugins vendor ).each do |dir|
    rm_rf File.join(dest, dir)
    cp_r dir, File.join(dest, dir)
  end

  `hash coffee`
  if not $?.success?
    abort "error: coffee is required but it's not installed - " +
          "http://coffeescript.org/ - (try `npm i -g coffee-script`)"
  end

  %w( src plugins ).each do |dir|
    Dir["#{dir}/**/*.coffee"].each do |file|
      sh "coffee -c #{dest}/#{dir}"
    end
  end
end

desc "Install the app in /Applications"
task :install do
  rm_rf "/Applications/Atomicity.app"
  cp_r "Cocoa/build/Debug/Atomicity.app /Applications"
end
