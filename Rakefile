ATOM_SRC_PATH = File.dirname(__FILE__)
DOT_ATOM_PATH = ENV['HOME'] + "/.atom"
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
task "create-xcode-project" => "bootstrap" do
  `rm -rf atom.xcodeproj`
  `gyp --depth=. atom.gyp`
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

  # Install cli atom
  usr_bin_path = "/opt/github/bin"
  cli_path = "#{usr_bin_path}/atom"

  template = ERB.new CLI_SCRIPT
  namespace = OpenStruct.new(:application_path => dest, :resource_path => ATOM_SRC_PATH)
  File.open(cli_path, "w") do |f|
    f.write template.result(namespace.instance_eval { binding })
    f.chmod(0755)
  end

  Rake::Task["create-dot-atom"].invoke()
  Rake::Task["clone-default-bundles"].invoke()

  puts "\033[32mType `atom` to start Atom! In Atom press `cmd-,` to edit your `~/.atom` directory\033[0m"
end

desc "Creates .atom file if non exists"
task "create-dot-atom" do
  dot_atom_template_path = ATOM_SRC_PATH + "/dot-atom"

  if File.exists?(DOT_ATOM_PATH)
    user_config = "#{DOT_ATOM_PATH}/user.coffee"
    old_user_config = "#{DOT_ATOM_PATH}/atom.coffee"

    if File.exists?(old_user_config)
      `mv #{old_user_config} #{user_config}`
      puts "\033[32mRenamed #{old_user_config} to #{user_config}\033[0m"
    end
  else
    `mkdir "#{DOT_ATOM_PATH}"`
    `cp -r "#{dot_atom_template_path}/" "#{DOT_ATOM_PATH}"/`
    `cp -r "#{ATOM_SRC_PATH}/themes/" "#{DOT_ATOM_PATH}"/themes/`
  end
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
task :test => ["clean", "clone-default-bundles"] do
  `pkill Atom`
  Rake::Task["run"].invoke("--test --resource-path=#{ATOM_SRC_PATH}")
end

desc "Run the benchmarks"
task :benchmark do
  Rake::Task["run"].invoke("--benchmark")
end

task :nof do
  system %{find . -name *spec.coffee | grep -v #{BUILD_DIR} | xargs sed -E -i "" "s/f+(it|describe) +(['\\"])/\\1 \\2/g"}
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

CLI_SCRIPT = <<-EOF
#!/bin/sh
open <%= application_path %> -n --args --resource-path="<%= resource_path %>" --executed-from="$(pwd)" --pid=$$ $@

# Used to exit process when atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# Don't exit process if we were told to wait.
while [ "$#" -gt "0" ]; do
  case $1 in
    -W|--wait)
      WAIT=1
      ;;
  esac
  shift
done

if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
EOF
