require 'timeout'

ATOM_SRC_PATH = File.dirname(__FILE__)
DOT_ATOM_PATH = ENV['HOME'] + "/.atom"
BUILD_DIR = 'atom-build'

desc "Build Atom via `xcodebuild`"
task :build => "create-project" do
  command = "xcodebuild -target Atom configuration=Release SYMROOT=#{BUILD_DIR}"
  output = `#{command}`
  if $?.exitstatus != 0
    $stderr.puts "Error #{$?.exitstatus}:\n#{output}"
    exit($?.exitstatus)
  end
end

desc "Create xcode project from gyp file"
task "create-project" => "bootstrap" do
  `rm -rf atom.xcodeproj`
  `gyp --depth=. atom.gyp`
end

task "bootstrap" do
  `script/bootstrap`
end

desc "Creates symlink from `application_path() to /Applications/Atom and creates `atom` cli app"
task :install => :build do
  path = application_path()
  exit 1 if not path

  # Install Atom.app
  dest =  "/Applications/#{File.basename(path)}"
  `rm -rf #{dest}`
  `cp -r #{path} #{File.expand_path(dest)}`

  # Install cli atom
  usr_bin_path = default_usr_bin_path = "/opt/github/bin"
  cli_path = "#{usr_bin_path}/atom"
  stable_cli_path = "#{usr_bin_path}/atom-stable"

  if !File.exists?(usr_bin_path)
    $stderr.puts "ERROR: Failed to install atom cli tool at '#{usr_bin_path}'"
    exit 1
  end

  `echo '#!/bin/sh\nopen #{dest} -n --args --resource-path="#{ATOM_SRC_PATH}" --executed-from="$(pwd)" $@' > #{cli_path} && chmod 755 #{cli_path}`
  `echo '#!/bin/sh\nopen #{dest} -n --args --resource-path="#{ATOM_SRC_PATH}" --executed-from="$(pwd)" --stable $@' > #{stable_cli_path} && chmod 755 #{stable_cli_path}`

  Rake::Task["create-dot-atom"].invoke()
  Rake::Task["clone-default-bundles"].invoke()

  puts "\033[32mType `atom` to start Atom! In Atom press `cmd-,` to edit your `.atom` directory\033[0m"
end

desc "Creates .atom file if non exists"
task "create-dot-atom" do
  dot_atom_template_path = ATOM_SRC_PATH + "/.atom"
  replace_dot_atom = false
  next if File.exists?(DOT_ATOM_PATH)

  `rm -rf "#{DOT_ATOM_PATH}"`
  `mkdir "#{DOT_ATOM_PATH}"`
  `cp "#{dot_atom_template_path}/atom.coffee" "#{DOT_ATOM_PATH}"`
  `cp "#{dot_atom_template_path}/bundles" "#{DOT_ATOM_PATH}"`

  for path in Dir.entries(dot_atom_template_path)
    next if ["..", ".", "atom.coffee", "bundles"].include? path
    `ln -s "#{dot_atom_template_path}/#{path}" "#{DOT_ATOM_PATH}"`
  end
end

desc "Clone default bundles into .atom directory"
task "clone-default-bundles" => "create-dot-atom" do
  bundles = {
    "https://github.com/textmate/css.tmbundle.git" => "HEAD",
    "https://github.com/textmate/html.tmbundle.git" => "HEAD",
    "https://github.com/textmate/javascript.tmbundle.git" => "58e81b0eae498c9a4eb6e395368df3b7a01d9851",
    "https://github.com/textmate/ruby-on-rails.tmbundle.git" => "HEAD",
    "https://github.com/textmate/ruby.tmbundle.git" => "daad8ef03de9630e74578a046240fd9acc63b8b5",
    "https://github.com/textmate/text.tmbundle.git" => "HEAD",
    "https://github.com/jashkenas/coffee-script-tmbundle.git" => "HEAD",
    "https://github.com/cburyta/puppet-textmate.tmbundle.git" => "HEAD",
    "https://github.com/textmate/c.tmbundle.git" => "c8a6516c1131055bfcd1bca5e2ee6567c2f50058",
  }

  for bundle_url, sha in bundles
    bundle_dir = bundle_url[/([^\/]+?)(\.git)?$/, 1]
    dest_path = File.join(DOT_ATOM_PATH, "bundles", bundle_dir)
    `git clone --quiet #{bundle_url} #{dest_path}` unless File.exists? dest_path
    `cd #{dest_path} && git reset --hard #{sha}`
  end
end

desc "Clean build Atom via `xcodebuild`"
task :clean do
  output = `xcodebuild clean`
end

desc "Run Atom"
task :run, [:atom_arg] => :build do |name, args|
  if path = application_path()
    cmd = "#{path}/Contents/MacOS/Atom #{args[:atom_arg]} 2> /dev/null"
    system(cmd)
    exit($?.exitstatus)
  else
    exit(1)
  end
end

desc "Run the specs"
task :test => ["clean", "clone-default-bundles"] do
  Rake::Task["run"].invoke("--test")
end

desc "Run the benchmarks"
task :benchmark do
  Rake::Task["run"].invoke("--benchmark")
end

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
