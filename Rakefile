ATOM_SRC_PATH = File.dirname(__FILE__)
BUILD_DIR = 'atom-build'

require 'erb'

desc "Build Atom via `xcodebuild`"
task :build => "create-xcode-project" do
  command = "xcodebuild -target Atom -configuration Release SYMROOT=#{BUILD_DIR}"
  output = `#{command}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Create xcode project from gyp file"
task "create-xcode-project" => "update-cef" do
  `rm -rf atom.xcodeproj`
  `gyp --depth=. atom.gyp`
end

desc "Update CEF to the latest version specified by the prebuilt-cef submodule"
task "update-cef" => "bootstrap" do
  exit 1 unless system %{prebuilt-cef/script/download -f cef}
  Dir.glob('cef/*.gypi').each do |filename|
    `sed -i '' -e "s/'include\\//'cef\\/include\\//" -e "s/'libcef_dll\\//'cef\\/libcef_dll\\//" #{filename}`
  end
end

task "bootstrap" do
  `script/bootstrap`
end

desc "Creates symlink from `application_path() to /Applications/Atom and creates `atom` cli app"
task :install => [:clean, :build] do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest =  "/Applications/#{File.basename(path)}"
  `rm -rf #{dest}`
  `cp -r #{path} #{File.expand_path(dest)}`

  Rake::Task["clone-default-bundles"].invoke()

  puts "\033[32mType `atom` to start Atom! In Atom press `cmd-,` to edit your `~/.atom` directory\033[0m"
end

desc "Deploy"
task :deploy => ["bump-patch-number", "build"] do
  path = application_path()
  exit 1 if not path

  dest_path = '/tmp/Atom.app.zip'
  `rm -rf #{dest_path}`
  `pushd $(dirname #{path}); zip -r #{dest_path} $(basename #{path}); popd`
end

desc "Bump patch number"
task "bump-patch-number" do
  version_number = `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString:" ./native/mac/info.plist`
  major, minor, patch = version_number.match(/(\d+)\.(\d+)\.(\d+)/)[1..-1].map {|o| o.to_i}
  `/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString #{major}.#{minor}.#{patch + 1}" ./native/mac/info.plist`
  `/usr/libexec/PlistBuddy -c "Set :CFBundleVersion #{major}.#{minor}.#{patch + 1}" ./native/mac/info.plist`

  new_version_number = `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString:" ./native/mac/info.plist`
  puts "Bumped from #{version_number.strip} to #{new_version_number.strip}"
end

desc "Clone default bundles into vendor/bundles directory"
task "clone-default-bundles" do
  `git submodule --quiet sync`
  `git submodule --quiet update --recursive --init`
end

desc "Clean build Atom via `xcodebuild`"
task :clean do
  output = `xcodebuild clean`
  `rm -rf #{application_path()}`
  `rm -rf #{BUILD_DIR}`
  `rm -rf /tmp/atom-compiled-scripts`
end

desc "Run the specs"
task :test => ["update-cef", "clone-default-bundles", "build"] do
  `pkill Atom`
  if path = application_path()
    `rm -rf path`
    cmd = "#{path}/Contents/MacOS/Atom --test --resource-path=#{ATOM_SRC_PATH} 2> /dev/null"
    system(cmd)
    exit($?.exitstatus)
  else
    exit(1)
  end
end

desc "Run the benchmarks"
task :benchmark do
  Rake::Task["run"].invoke("--benchmark")
end

task :nof do
  system %{find . -name *spec.coffee | grep --invert-match --regexp "#{BUILD_DIR}\\|##package-name##" | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
end

task :tags do
  system %{find src native cef vendor -not -name "*spec.coffee" -type f -print0 | xargs -0 ctags}
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
