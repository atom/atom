ATOM_SRC_PATH = File.dirname(__FILE__)
BUILD_DIR = 'atom-build'

desc "Build Atom via `xcodebuild`"
task :build => "create-xcode-project" do
  command = "xcodebuild -target Atom -configuration Release SYMROOT=#{BUILD_DIR}"
  sh command do |ok, res|
    unless ok
      $stderr.puts "Error #{res.exitstatus}:\n#{output}"
      exit(res.exitstatus)
    end
  end
end

desc "Create xcode project from gyp file"
task "create-xcode-project" => "update-cef" do
  sh %{rm -rf atom.xcodeproj}
  sh %{gyp --depth=. -D CODE_SIGN="#{ENV['CODE_SIGN']}" atom.gyp}
end

desc "Update CEF to the latest version specified by the prebuilt-cef submodule"
task "update-cef" => "bootstrap" do
  sh %{prebuilt-cef/script/download -f cef} do |ok, res|
    exit res.statuscode unless ok
  end
  Dir.glob('cef/*.gypi').each do |filename|
    `sed -i '' -e "s/'include\\//'cef\\/include\\//" -e "s/'libcef_dll\\//'cef\\/libcef_dll\\//" #{filename}`
  end
end

task "bootstrap" do
  sh %{script/bootstrap}
end

desc "Copies Atom.app to /Applications and creates `atom` cli app"
task :install => [:clean, :build] do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest_path =  "/Applications/#{File.basename(path)}"
  sh %{rm -rf #{dest_path}}
  sh %{cp -r #{path} #{File.expand_path(dest_path)}}

  # Install atom cli
  if File.directory?("/opt/boxen")
    cli_path = "/opt/boxen/bin/atom"
  else
    cli_path = "/opt/github/bin/atom"
  end

  FileUtils.cp("#{ATOM_SRC_PATH}/atom.sh", cli_path)
  FileUtils.chmod(0755, cli_path)

  Rake::Task["clone-default-bundles"].invoke()

  puts "\033[32mAtom is installed at `#{dest_path}`. Atom cli is installed at `#{cli_path}`\033[0m"
end

desc "Package up the app for speakeasy"
task :package => ["setup-codesigning", "bump-patch-number", "build"] do
  path = application_path()
  exit 1 if not path

  dest_path = '/tmp/atom-for-speakeasy/Atom.tar.bz2'
  sh %{mkdir -p $(dirname #{dest_path})}
  sh %{rm -rf #{dest_path}}
  sh %{tar --directory $(dirname #{path}) -jcf #{dest_path} $(basename #{path})}
  sh %{open $(dirname #{dest_path})}
end

task "setup-codesigning" do
  ENV['CODE_SIGN'] = "Developer ID Application: GitHub"
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
  sh %{git submodule --quiet sync}
  sh %{git submodule --quiet update --recursive --init}
end

desc "Clean build Atom via `xcodebuild`"
task :clean do
  output = `xcodebuild clean`
  sh %{rm -rf #{application_path()}}
  sh %{rm -rf #{BUILD_DIR}}
  sh %{rm -rf /tmp/atom-compiled-scripts}
end

desc "Run the specs"
task :test => ["update-cef", "clone-default-bundles", "build"] do
  sh %{pkill Atom}
  if path = application_path()
    sh %{rm -rf path}
    sh "#{path}/Contents/MacOS/Atom --test --resource-path=#{ATOM_SRC_PATH}" do |ok, res|
      exit(res.exitstatus) unless ok
    end
  else
    puts "Couldn't find Atom!"
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
