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
task "create-xcode-project" => ["update-atom-shell"] do
  `rm -rf atom.xcodeproj`
  `script/generate-sources-gypi`
  version = %{-D version="#{ENV['VERSION']}"} if ENV['VERSION']
  code_sign = %{-D code_sign="#{ENV['CODE_SIGN']}"} if ENV['CODE_SIGN']
  `gyp --depth=. #{code_sign} #{version} atom.gyp`
end

desc "Update to latest atom-shell"
task "update-atom-shell" => "bootstrap" do
  exit 1 unless system %{script/update-atom-shell}
end

task "bootstrap" do
  `script/bootstrap`
end

desc "Copies Atom.app to /Applications"
task :install => [:build] do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest_path =  "/Applications/#{File.basename(path)}"
  `rm -rf #{dest_path}`
  `cp -a #{path} #{File.expand_path(dest_path)}`

  puts "\033[32mAtom is installed at `#{dest_path}`.\033[0m"
end

task "setup-codesigning" do
  ENV['CODE_SIGN'] = "Developer ID Application: GitHub"
end

desc "Clean build Atom via `xcodebuild`"
task :clean do
  output = `xcodebuild clean`
  `rm -rf #{application_path()}`
  `rm -rf #{BUILD_DIR}`
  `rm -rf /tmp/atom-coffee-cache`
  `rm -rf /tmp/atom-cached-atom-shells`
  `rm -rf node_modules`
  `rm -rf atom-shell`
end

desc "Run the specs"
task :test => ["build"] do
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
  system %{find src native vendor -not -name "*spec.coffee" -type f -print0 | xargs -0 ctags}
end

namespace :docs do
  namespace :app do
    desc "Builds the API docs in src/app"
    task :build do
      system %{./node_modules/.bin/coffee ./node_modules/.bin/biscotto -- -o docs/api src/app/}
    end

    desc "Lists the stats for API doc coverage in src/app"
    task :stats do
      system %{./node_modules/.bin/coffee ./node_modules/.bin/biscotto -- --statsOnly src/app/}
    end

    desc "Show which docs are missing"
    task :missing do
      system %{./node_modules/.bin/coffee ./node_modules/.bin/biscotto -- --listMissing src/app/}
    end
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
