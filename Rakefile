ATOM_SRC_PATH = File.dirname(__FILE__)
BUILD_DIR = '/tmp/atom-build'

desc "Build Atom via `xcodebuild`"
task :build => "create-xcode-project" do
  command = "xcodebuild -target Atom SYMROOT=#{BUILD_DIR}"
  output = `#{command}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Create xcode project from gyp file"
task "create-xcode-project" => ["update-cef", "update-node"] do
  `rm -rf atom.xcodeproj`
  `script/generate-sources-gypi`
  `gyp --depth=. -D CODE_SIGN="#{ENV['CODE_SIGN']}" atom.gyp`
end

desc "Update CEF to the latest version specified by the prebuilt-cef submodule"
task "update-cef" => "bootstrap" do
  exit 1 unless system %{script/update-cefode}
  Dir.glob('cef/*.gypi').each do |filename|
    `sed -i '' -e "s/'include\\//'cef\\/include\\//" -e "s/'libcef_dll\\//'cef\\/libcef_dll\\//" #{filename}`
  end
end

desc "Download node binary"
task "update-node" do
  `script/update-node v0.10.1`
end

desc "Download debug symbols for CEF"
task "download-cef-symbols" => "update-cef" do
  sh %{script/update-cefode -s}
end

task "bootstrap" do
  `script/bootstrap`
end

desc "Copies Atom.app to /Applications and creates `atom` cli app"
task :install => [:build] do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest_path =  "/Applications/#{File.basename(path)}"
  `rm -rf #{dest_path}`
  `cp -a #{path} #{File.expand_path(dest_path)}`

  # Install atom cli
  if File.directory?("/opt/boxen")
    cli_path = "/opt/boxen/bin/atom"
  elsif File.directory?("/opt/github")
    cli_path = "/opt/github/bin/atom"
  elsif File.directory?("/usr/local")
    cli_path = "/usr/local/bin/atom"
  else
    raise "Missing directory for `atom` binary"
  end

  FileUtils.cp("#{ATOM_SRC_PATH}/atom.sh", cli_path)
  FileUtils.chmod(0755, cli_path)

  Rake::Task["clone-default-bundles"].invoke()

  puts "\033[32mAtom is installed at `#{dest_path}`. Atom cli is installed at `#{cli_path}`\033[0m"
end

task "setup-codesigning" do
  ENV['CODE_SIGN'] = "Developer ID Application: GitHub"
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
  `rm -rf /tmp/atom-coffee-cache`
  `rm -rf node_modules`
  `rm -rf cef`
end

desc "Run the specs"
task :test => ["clean", "update-cef", "clone-default-bundles", "build"] do
  `pkill Atom`
  if path = application_path()
    cmd = "#{path}/Contents/MacOS/Atom --test --resource-path=#{ATOM_SRC_PATH}"
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
  system %{find . -name *spec.coffee | grep --invert-match --regexp "#{BUILD_DIR}\\|__package-name__" | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
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
