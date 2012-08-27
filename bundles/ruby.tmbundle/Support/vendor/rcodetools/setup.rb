#
# setup.rb
#
# Copyright (c) 2000-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

unless Enumerable.method_defined?(:map)   # Ruby 1.4.6
  module Enumerable
    alias map collect
  end
end

unless File.respond_to?(:read)   # Ruby 1.6
  def File.read(fname)
    open(fname) {|f|
      return f.read
    }
  end
end

unless Errno.const_defined?(:ENOTEMPTY)   # Windows?
  module Errno
    class ENOTEMPTY
      # We do not raise this exception, implementation is not needed.
    end
  end
end

def File.binread(fname)
  open(fname, 'rb') {|f|
    return f.read
  }
end

# for corrupted Windows' stat(2)
def File.dir?(path)
  File.directory?((path[-1,1] == '/') ? path : path + '/')
end


class ConfigTable

  include Enumerable

  def initialize(rbconfig)
    @rbconfig = rbconfig
    @items = []
    @table = {}
    # options
    @install_prefix = nil
    @config_opt = nil
    @verbose = true
    @no_harm = false
  end

  attr_accessor :install_prefix
  attr_accessor :config_opt

  attr_writer :verbose

  def verbose?
    @verbose
  end

  attr_writer :no_harm

  def no_harm?
    @no_harm
  end

  def [](key)
    lookup(key).resolve(self)
  end

  def []=(key, val)
    lookup(key).set val
  end

  def names
    @items.map {|i| i.name }
  end

  def each(&block)
    @items.each(&block)
  end

  def key?(name)
    @table.key?(name)
  end

  def lookup(name)
    @table[name] or setup_rb_error "no such config item: #{name}"
  end

  def add(item)
    @items.push item
    @table[item.name] = item
  end

  def remove(name)
    item = lookup(name)
    @items.delete_if {|i| i.name == name }
    @table.delete_if {|name, i| i.name == name }
    item
  end

  def load_script(path, inst = nil)
    if File.file?(path)
      MetaConfigEnvironment.new(self, inst).instance_eval File.read(path), path
    end
  end

  def savefile
    '.config'
  end

  def load_savefile
    begin
      File.foreach(savefile()) do |line|
        k, v = *line.split(/=/, 2)
        self[k] = v.strip
      end
    rescue Errno::ENOENT
      setup_rb_error $!.message + "\n#{File.basename($0)} config first"
    end
  end

  def save
    @items.each {|i| i.value }
    File.open(savefile(), 'w') {|f|
      @items.each do |i|
        f.printf "%s=%s\n", i.name, i.value if i.value? and i.value
      end
    }
  end

  def load_standard_entries
    standard_entries(@rbconfig).each do |ent|
      add ent
    end
  end

  def standard_entries(rbconfig)
    c = rbconfig

    rubypath = File.join(c['bindir'], c['ruby_install_name'] + c['EXEEXT'])

    major = c['MAJOR'].to_i
    minor = c['MINOR'].to_i
    teeny = c['TEENY'].to_i
    version = "#{major}.#{minor}"

    # ruby ver. >= 1.4.4?
    newpath_p = ((major >= 2) or
                 ((major == 1) and
                  ((minor >= 5) or
                   ((minor == 4) and (teeny >= 4)))))

    if c['rubylibdir']
      # V > 1.6.3
      libruby         = "#{c['prefix']}/lib/ruby"
      librubyver      = c['rubylibdir']
      librubyverarch  = c['archdir']
      siteruby        = c['sitedir']
      siterubyver     = c['sitelibdir']
      siterubyverarch = c['sitearchdir']
    elsif newpath_p
      # 1.4.4 <= V <= 1.6.3
      libruby         = "#{c['prefix']}/lib/ruby"
      librubyver      = "#{c['prefix']}/lib/ruby/#{version}"
      librubyverarch  = "#{c['prefix']}/lib/ruby/#{version}/#{c['arch']}"
      siteruby        = c['sitedir']
      siterubyver     = "$siteruby/#{version}"
      siterubyverarch = "$siterubyver/#{c['arch']}"
    else
      # V < 1.4.4
      libruby         = "#{c['prefix']}/lib/ruby"
      librubyver      = "#{c['prefix']}/lib/ruby/#{version}"
      librubyverarch  = "#{c['prefix']}/lib/ruby/#{version}/#{c['arch']}"
      siteruby        = "#{c['prefix']}/lib/ruby/#{version}/site_ruby"
      siterubyver     = siteruby
      siterubyverarch = "$siterubyver/#{c['arch']}"
    end
    parameterize = lambda {|path|
      path.sub(/\A#{Regexp.quote(c['prefix'])}/, '$prefix')
    }

    if arg = c['configure_args'].split.detect {|arg| /--with-make-prog=/ =~ arg }
      makeprog = arg.sub(/'/, '').split(/=/, 2)[1]
    else
      makeprog = 'make'
    end

    [
      ExecItem.new('installdirs', 'std/site/home',
                   'std: install under libruby; site: install under site_ruby; home: install under $HOME')\
          {|val, table|
            case val
            when 'std'
              table['rbdir'] = '$librubyver'
              table['sodir'] = '$librubyverarch'
            when 'site'
              table['rbdir'] = '$siterubyver'
              table['sodir'] = '$siterubyverarch'
            when 'home'
              setup_rb_error '$HOME was not set' unless ENV['HOME']
              table['prefix'] = ENV['HOME']
              table['rbdir'] = '$libdir/ruby'
              table['sodir'] = '$libdir/ruby'
            end
          },
      PathItem.new('prefix', 'path', c['prefix'],
                   'path prefix of target environment'),
      PathItem.new('bindir', 'path', parameterize.call(c['bindir']),
                   'the directory for commands'),
      PathItem.new('libdir', 'path', parameterize.call(c['libdir']),
                   'the directory for libraries'),
      PathItem.new('datadir', 'path', parameterize.call(c['datadir']),
                   'the directory for shared data'),
      PathItem.new('mandir', 'path', parameterize.call(c['mandir']),
                   'the directory for man pages'),
      PathItem.new('sysconfdir', 'path', parameterize.call(c['sysconfdir']),
                   'the directory for system configuration files'),
      PathItem.new('localstatedir', 'path', parameterize.call(c['localstatedir']),
                   'the directory for local state data'),
      PathItem.new('libruby', 'path', libruby,
                   'the directory for ruby libraries'),
      PathItem.new('librubyver', 'path', librubyver,
                   'the directory for standard ruby libraries'),
      PathItem.new('librubyverarch', 'path', librubyverarch,
                   'the directory for standard ruby extensions'),
      PathItem.new('siteruby', 'path', siteruby,
          'the directory for version-independent aux ruby libraries'),
      PathItem.new('siterubyver', 'path', siterubyver,
                   'the directory for aux ruby libraries'),
      PathItem.new('siterubyverarch', 'path', siterubyverarch,
                   'the directory for aux ruby binaries'),
      PathItem.new('rbdir', 'path', '$siterubyver',
                   'the directory for ruby scripts'),
      PathItem.new('sodir', 'path', '$siterubyverarch',
                   'the directory for ruby extentions'),
      PathItem.new('rubypath', 'path', rubypath,
                   'the path to set to #! line'),
      ProgramItem.new('rubyprog', 'name', rubypath,
                      'the ruby program using for installation'),
      ProgramItem.new('makeprog', 'name', makeprog,
                      'the make program to compile ruby extentions'),
      SelectItem.new('shebang', 'all/ruby/never', 'ruby',
                     'shebang line (#!) editing mode'),
      BoolItem.new('without-ext', 'yes/no', 'no',
                   'does not compile/install ruby extentions')
    ]
  end
  private :standard_entries

  def load_multipackage_entries
    multipackage_entries().each do |ent|
      add ent
    end
  end

  def multipackage_entries
    [
      PackageSelectionItem.new('with', 'name,name...', '', 'ALL',
                               'package names that you want to install'),
      PackageSelectionItem.new('without', 'name,name...', '', 'NONE',
                               'package names that you do not want to install')
    ]
  end
  private :multipackage_entries

  ALIASES = {
    'std-ruby'         => 'librubyver',
    'stdruby'          => 'librubyver',
    'rubylibdir'       => 'librubyver',
    'archdir'          => 'librubyverarch',
    'site-ruby-common' => 'siteruby',     # For backward compatibility
    'site-ruby'        => 'siterubyver',  # For backward compatibility
    'bin-dir'          => 'bindir',
    'bin-dir'          => 'bindir',
    'rb-dir'           => 'rbdir',
    'so-dir'           => 'sodir',
    'data-dir'         => 'datadir',
    'ruby-path'        => 'rubypath',
    'ruby-prog'        => 'rubyprog',
    'ruby'             => 'rubyprog',
    'make-prog'        => 'makeprog',
    'make'             => 'makeprog'
  }

  def fixup
    ALIASES.each do |ali, name|
      @table[ali] = @table[name]
    end
    @items.freeze
    @table.freeze
    @options_re = /\A--(#{@table.keys.join('|')})(?:=(.*))?\z/
  end

  def parse_opt(opt)
    m = @options_re.match(opt) or setup_rb_error "config: unknown option #{opt}"
    m.to_a[1,2]
  end

  def dllext
    @rbconfig['DLEXT']
  end

  def value_config?(name)
    lookup(name).value?
  end

  class Item
    def initialize(name, template, default, desc)
      @name = name.freeze
      @template = template
      @value = default
      @default = default
      @description = desc
    end

    attr_reader :name
    attr_reader :description

    attr_accessor :default
    alias help_default default

    def help_opt
      "--#{@name}=#{@template}"
    end

    def value?
      true
    end

    def value
      @value
    end

    def resolve(table)
      @value.gsub(%r<\$([^/]+)>) { table[$1] }
    end

    def set(val)
      @value = check(val)
    end

    private

    def check(val)
      setup_rb_error "config: --#{name} requires argument" unless val
      val
    end
  end

  class BoolItem < Item
    def config_type
      'bool'
    end

    def help_opt
      "--#{@name}"
    end

    private

    def check(val)
      return 'yes' unless val
      case val
      when /\Ay(es)?\z/i, /\At(rue)?\z/i then 'yes'
      when /\An(o)?\z/i, /\Af(alse)\z/i  then 'no'
      else
        setup_rb_error "config: --#{@name} accepts only yes/no for argument"
      end
    end
  end

  class PathItem < Item
    def config_type
      'path'
    end

    private

    def check(path)
      setup_rb_error "config: --#{@name} requires argument"  unless path
      path[0,1] == '$' ? path : File.expand_path(path)
    end
  end

  class ProgramItem < Item
    def config_type
      'program'
    end
  end

  class SelectItem < Item
    def initialize(name, selection, default, desc)
      super
      @ok = selection.split('/')
    end

    def config_type
      'select'
    end

    private

    def check(val)
      unless @ok.include?(val.strip)
        setup_rb_error "config: use --#{@name}=#{@template} (#{val})"
      end
      val.strip
    end
  end

  class ExecItem < Item
    def initialize(name, selection, desc, &block)
      super name, selection, nil, desc
      @ok = selection.split('/')
      @action = block
    end

    def config_type
      'exec'
    end

    def value?
      false
    end

    def resolve(table)
      setup_rb_error "$#{name()} wrongly used as option value"
    end

    undef set

    def evaluate(val, table)
      v = val.strip.downcase
      unless @ok.include?(v)
        setup_rb_error "invalid option --#{@name}=#{val} (use #{@template})"
      end
      @action.call v, table
    end
  end

  class PackageSelectionItem < Item
    def initialize(name, template, default, help_default, desc)
      super name, template, default, desc
      @help_default = help_default
    end

    attr_reader :help_default

    def config_type
      'package'
    end

    private

    def check(val)
      unless File.dir?("packages/#{val}")
        setup_rb_error "config: no such package: #{val}"
      end
      val
    end
  end

  class MetaConfigEnvironment
    def initialize(config, installer)
      @config = config
      @installer = installer
    end

    def config_names
      @config.names
    end

    def config?(name)
      @config.key?(name)
    end

    def bool_config?(name)
      @config.lookup(name).config_type == 'bool'
    end

    def path_config?(name)
      @config.lookup(name).config_type == 'path'
    end

    def value_config?(name)
      @config.lookup(name).config_type != 'exec'
    end

    def add_config(item)
      @config.add item
    end

    def add_bool_config(name, default, desc)
      @config.add BoolItem.new(name, 'yes/no', default ? 'yes' : 'no', desc)
    end

    def add_path_config(name, default, desc)
      @config.add PathItem.new(name, 'path', default, desc)
    end

    def set_config_default(name, default)
      @config.lookup(name).default = default
    end

    def remove_config(name)
      @config.remove(name)
    end

    # For only multipackage
    def packages
      raise '[setup.rb fatal] multi-package metaconfig API packages() called for single-package; contact application package vendor' unless @installer
      @installer.packages
    end

    # For only multipackage
    def declare_packages(list)
      raise '[setup.rb fatal] multi-package metaconfig API declare_packages() called for single-package; contact application package vendor' unless @installer
      @installer.packages = list
    end
  end

end   # class ConfigTable


# This module requires: #verbose?, #no_harm?
module FileOperations

  def mkdir_p(dirname, prefix = nil)
    dirname = prefix + File.expand_path(dirname) if prefix
    $stderr.puts "mkdir -p #{dirname}" if verbose?
    return if no_harm?

    # Does not check '/', it's too abnormal.
    dirs = File.expand_path(dirname).split(%r<(?=/)>)
    if /\A[a-z]:\z/i =~ dirs[0]
      disk = dirs.shift
      dirs[0] = disk + dirs[0]
    end
    dirs.each_index do |idx|
      path = dirs[0..idx].join('')
      Dir.mkdir path unless File.dir?(path)
    end
  end

  def rm_f(path)
    $stderr.puts "rm -f #{path}" if verbose?
    return if no_harm?
    force_remove_file path
  end

  def rm_rf(path)
    $stderr.puts "rm -rf #{path}" if verbose?
    return if no_harm?
    remove_tree path
  end

  def remove_tree(path)
    if File.symlink?(path)
      remove_file path
    elsif File.dir?(path)
      remove_tree0 path
    else
      force_remove_file path
    end
  end

  def remove_tree0(path)
    Dir.foreach(path) do |ent|
      next if ent == '.'
      next if ent == '..'
      entpath = "#{path}/#{ent}"
      if File.symlink?(entpath)
        remove_file entpath
      elsif File.dir?(entpath)
        remove_tree0 entpath
      else
        force_remove_file entpath
      end
    end
    begin
      Dir.rmdir path
    rescue Errno::ENOTEMPTY
      # directory may not be empty
    end
  end

  def move_file(src, dest)
    force_remove_file dest
    begin
      File.rename src, dest
    rescue
      File.open(dest, 'wb') {|f|
        f.write File.binread(src)
      }
      File.chmod File.stat(src).mode, dest
      File.unlink src
    end
  end

  def force_remove_file(path)
    begin
      remove_file path
    rescue
    end
  end

  def remove_file(path)
    File.chmod 0777, path
    File.unlink path
  end

  def install(from, dest, mode, prefix = nil)
    $stderr.puts "install #{from} #{dest}" if verbose?
    return if no_harm?

    realdest = prefix ? prefix + File.expand_path(dest) : dest
    realdest = File.join(realdest, File.basename(from)) if File.dir?(realdest)
    str = File.binread(from)
    if diff?(str, realdest)
      verbose_off {
        rm_f realdest if File.exist?(realdest)
      }
      File.open(realdest, 'wb') {|f|
        f.write str
      }
      File.chmod mode, realdest

      File.open("#{objdir_root()}/InstalledFiles", 'a') {|f|
        if prefix
          f.puts realdest.sub(prefix, '')
        else
          f.puts realdest
        end
      }
    end
  end

  def diff?(new_content, path)
    return true unless File.exist?(path)
    new_content != File.binread(path)
  end

  def command(*args)
    $stderr.puts args.join(' ') if verbose?
    system(*args) or raise RuntimeError,
        "system(#{args.map{|a| a.inspect }.join(' ')}) failed"
  end

  def ruby(*args)
    command config('rubyprog'), *args
  end
  
  def make(task = nil)
    command(*[config('makeprog'), task].compact)
  end

  def extdir?(dir)
    File.exist?("#{dir}/MANIFEST") or File.exist?("#{dir}/extconf.rb")
  end

  def files_of(dir)
    Dir.open(dir) {|d|
      return d.select {|ent| File.file?("#{dir}/#{ent}") }
    }
  end

  DIR_REJECT = %w( . .. CVS SCCS RCS CVS.adm .svn )

  def directories_of(dir)
    Dir.open(dir) {|d|
      return d.select {|ent| File.dir?("#{dir}/#{ent}") } - DIR_REJECT
    }
  end

end


# This module requires: #srcdir_root, #objdir_root, #relpath
module HookScriptAPI

  def get_config(key)
    @config[key]
  end

  alias config get_config

  # obsolete: use metaconfig to change configuration
  def set_config(key, val)
    @config[key] = val
  end

  #
  # srcdir/objdir (works only in the package directory)
  #

  def curr_srcdir
    "#{srcdir_root()}/#{relpath()}"
  end

  def curr_objdir
    "#{objdir_root()}/#{relpath()}"
  end

  def srcfile(path)
    "#{curr_srcdir()}/#{path}"
  end

  def srcexist?(path)
    File.exist?(srcfile(path))
  end

  def srcdirectory?(path)
    File.dir?(srcfile(path))
  end
  
  def srcfile?(path)
    File.file?(srcfile(path))
  end

  def srcentries(path = '.')
    Dir.open("#{curr_srcdir()}/#{path}") {|d|
      return d.to_a - %w(. ..)
    }
  end

  def srcfiles(path = '.')
    srcentries(path).select {|fname|
      File.file?(File.join(curr_srcdir(), path, fname))
    }
  end

  def srcdirectories(path = '.')
    srcentries(path).select {|fname|
      File.dir?(File.join(curr_srcdir(), path, fname))
    }
  end

end


class ToplevelInstaller

  Version   = '3.4.1'
  Copyright = 'Copyright (c) 2000-2005 Minero Aoki'

  TASKS = [
    [ 'all',      'do config, setup, then install' ],
    [ 'config',   'saves your configurations' ],
    [ 'show',     'shows current configuration' ],
    [ 'setup',    'compiles ruby extentions and others' ],
    [ 'install',  'installs files' ],
    [ 'test',     'run all tests in test/' ],
    [ 'clean',    "does `make clean' for each extention" ],
    [ 'distclean',"does `make distclean' for each extention" ]
  ]

  def ToplevelInstaller.invoke
    config = ConfigTable.new(load_rbconfig())
    config.load_standard_entries
    config.load_multipackage_entries if multipackage?
    config.fixup
    klass = (multipackage?() ? ToplevelInstallerMulti : ToplevelInstaller)
    klass.new(File.dirname($0), config).invoke
  end

  def ToplevelInstaller.multipackage?
    File.dir?(File.dirname($0) + '/packages')
  end

  def ToplevelInstaller.load_rbconfig
    if arg = ARGV.detect {|arg| /\A--rbconfig=/ =~ arg }
      ARGV.delete(arg)
      load File.expand_path(arg.split(/=/, 2)[1])
      $".push 'rbconfig.rb'
    else
      require 'rbconfig'
    end
    ::Config::CONFIG
  end

  def initialize(ardir_root, config)
    @ardir = File.expand_path(ardir_root)
    @config = config
    # cache
    @valid_task_re = nil
  end

  def config(key)
    @config[key]
  end

  def inspect
    "#<#{self.class} #{__id__()}>"
  end

  def invoke
    run_metaconfigs
    case task = parsearg_global()
    when nil, 'all'
      parsearg_config
      init_installers
      exec_config
      exec_setup
      exec_install
    else
      case task
      when 'config', 'test'
        ;
      when 'clean', 'distclean'
        @config.load_savefile if File.exist?(@config.savefile)
      else
        @config.load_savefile
      end
      __send__ "parsearg_#{task}"
      init_installers
      __send__ "exec_#{task}"
    end
  end
  
  def run_metaconfigs
    @config.load_script "#{@ardir}/metaconfig"
  end

  def init_installers
    @installer = Installer.new(@config, @ardir, File.expand_path('.'))
  end

  #
  # Hook Script API bases
  #

  def srcdir_root
    @ardir
  end

  def objdir_root
    '.'
  end

  def relpath
    '.'
  end

  #
  # Option Parsing
  #

  def parsearg_global
    while arg = ARGV.shift
      case arg
      when /\A\w+\z/
        setup_rb_error "invalid task: #{arg}" unless valid_task?(arg)
        return arg
      when '-q', '--quiet'
        @config.verbose = false
      when '--verbose'
        @config.verbose = true
      when '--help'
        print_usage $stdout
        exit 0
      when '--version'
        puts "#{File.basename($0)} version #{Version}"
        exit 0
      when '--copyright'
        puts Copyright
        exit 0
      else
        setup_rb_error "unknown global option '#{arg}'"
      end
    end
    nil
  end

  def valid_task?(t)
    valid_task_re() =~ t
  end

  def valid_task_re
    @valid_task_re ||= /\A(?:#{TASKS.map {|task,desc| task }.join('|')})\z/
  end

  def parsearg_no_options
    unless ARGV.empty?
      task = caller(0).first.slice(%r<`parsearg_(\w+)'>, 1)
      setup_rb_error "#{task}: unknown options: #{ARGV.join(' ')}"
    end
  end

  alias parsearg_show       parsearg_no_options
  alias parsearg_setup      parsearg_no_options
  alias parsearg_test       parsearg_no_options
  alias parsearg_clean      parsearg_no_options
  alias parsearg_distclean  parsearg_no_options

  def parsearg_config
    evalopt = []
    set = []
    @config.config_opt = []
    while i = ARGV.shift
      if /\A--?\z/ =~ i
        @config.config_opt = ARGV.dup
        break
      end
      name, value = *@config.parse_opt(i)
      if @config.value_config?(name)
        @config[name] = value
      else
        evalopt.push [name, value]
      end
      set.push name
    end
    evalopt.each do |name, value|
      @config.lookup(name).evaluate value, @config
    end
    # Check if configuration is valid
    set.each do |n|
      @config[n] if @config.value_config?(n)
    end
  end

  def parsearg_install
    @config.no_harm = false
    @config.install_prefix = ''
    while a = ARGV.shift
      case a
      when '--no-harm'
        @config.no_harm = true
      when /\A--prefix=/
        path = a.split(/=/, 2)[1]
        path = File.expand_path(path) unless path[0,1] == '/'
        @config.install_prefix = path
      else
        setup_rb_error "install: unknown option #{a}"
      end
    end
  end

  def print_usage(out)
    out.puts 'Typical Installation Procedure:'
    out.puts "  $ ruby #{File.basename $0} config"
    out.puts "  $ ruby #{File.basename $0} setup"
    out.puts "  # ruby #{File.basename $0} install (may require root privilege)"
    out.puts
    out.puts 'Detailed Usage:'
    out.puts "  ruby #{File.basename $0} <global option>"
    out.puts "  ruby #{File.basename $0} [<global options>] <task> [<task options>]"

    fmt = "  %-24s %s\n"
    out.puts
    out.puts 'Global options:'
    out.printf fmt, '-q,--quiet',   'suppress message outputs'
    out.printf fmt, '   --verbose', 'output messages verbosely'
    out.printf fmt, '   --help',    'print this message'
    out.printf fmt, '   --version', 'print version and quit'
    out.printf fmt, '   --copyright',  'print copyright and quit'
    out.puts
    out.puts 'Tasks:'
    TASKS.each do |name, desc|
      out.printf fmt, name, desc
    end

    fmt = "  %-24s %s [%s]\n"
    out.puts
    out.puts 'Options for CONFIG or ALL:'
    @config.each do |item|
      out.printf fmt, item.help_opt, item.description, item.help_default
    end
    out.printf fmt, '--rbconfig=path', 'rbconfig.rb to load',"running ruby's"
    out.puts
    out.puts 'Options for INSTALL:'
    out.printf fmt, '--no-harm', 'only display what to do if given', 'off'
    out.printf fmt, '--prefix=path',  'install path prefix', ''
    out.puts
  end

  #
  # Task Handlers
  #

  def exec_config
    @installer.exec_config
    @config.save   # must be final
  end

  def exec_setup
    @installer.exec_setup
  end

  def exec_install
    @installer.exec_install
  end

  def exec_test
    @installer.exec_test
  end

  def exec_show
    @config.each do |i|
      printf "%-20s %s\n", i.name, i.value if i.value?
    end
  end

  def exec_clean
    @installer.exec_clean
  end

  def exec_distclean
    @installer.exec_distclean
  end

end   # class ToplevelInstaller


class ToplevelInstallerMulti < ToplevelInstaller

  include FileOperations

  def initialize(ardir_root, config)
    super
    @packages = directories_of("#{@ardir}/packages")
    raise 'no package exists' if @packages.empty?
    @root_installer = Installer.new(@config, @ardir, File.expand_path('.'))
  end

  def run_metaconfigs
    @config.load_script "#{@ardir}/metaconfig", self
    @packages.each do |name|
      @config.load_script "#{@ardir}/packages/#{name}/metaconfig"
    end
  end

  attr_reader :packages

  def packages=(list)
    raise 'package list is empty' if list.empty?
    list.each do |name|
      raise "directory packages/#{name} does not exist"\
              unless File.dir?("#{@ardir}/packages/#{name}")
    end
    @packages = list
  end

  def init_installers
    @installers = {}
    @packages.each do |pack|
      @installers[pack] = Installer.new(@config,
                                       "#{@ardir}/packages/#{pack}",
                                       "packages/#{pack}")
    end
    with    = extract_selection(config('with'))
    without = extract_selection(config('without'))
    @selected = @installers.keys.select {|name|
                  (with.empty? or with.include?(name)) \
                      and not without.include?(name)
                }
  end

  def extract_selection(list)
    a = list.split(/,/)
    a.each do |name|
      setup_rb_error "no such package: #{name}"  unless @installers.key?(name)
    end
    a
  end

  def print_usage(f)
    super
    f.puts 'Inluded packages:'
    f.puts '  ' + @packages.sort.join(' ')
    f.puts
  end

  #
  # Task Handlers
  #

  def exec_config
    run_hook 'pre-config'
    each_selected_installers {|inst| inst.exec_config }
    run_hook 'post-config'
    @config.save   # must be final
  end

  def exec_setup
    run_hook 'pre-setup'
    each_selected_installers {|inst| inst.exec_setup }
    run_hook 'post-setup'
  end

  def exec_install
    run_hook 'pre-install'
    each_selected_installers {|inst| inst.exec_install }
    run_hook 'post-install'
  end

  def exec_test
    run_hook 'pre-test'
    each_selected_installers {|inst| inst.exec_test }
    run_hook 'post-test'
  end

  def exec_clean
    rm_f @config.savefile
    run_hook 'pre-clean'
    each_selected_installers {|inst| inst.exec_clean }
    run_hook 'post-clean'
  end

  def exec_distclean
    rm_f @config.savefile
    run_hook 'pre-distclean'
    each_selected_installers {|inst| inst.exec_distclean }
    run_hook 'post-distclean'
  end

  #
  # lib
  #

  def each_selected_installers
    Dir.mkdir 'packages' unless File.dir?('packages')
    @selected.each do |pack|
      $stderr.puts "Processing the package `#{pack}' ..." if verbose?
      Dir.mkdir "packages/#{pack}" unless File.dir?("packages/#{pack}")
      Dir.chdir "packages/#{pack}"
      yield @installers[pack]
      Dir.chdir '../..'
    end
  end

  def run_hook(id)
    @root_installer.run_hook id
  end

  # module FileOperations requires this
  def verbose?
    @config.verbose?
  end

  # module FileOperations requires this
  def no_harm?
    @config.no_harm?
  end

end   # class ToplevelInstallerMulti


class Installer

  FILETYPES = %w( bin lib ext data conf man )

  include FileOperations
  include HookScriptAPI

  def initialize(config, srcroot, objroot)
    @config = config
    @srcdir = File.expand_path(srcroot)
    @objdir = File.expand_path(objroot)
    @currdir = '.'
  end

  def inspect
    "#<#{self.class} #{File.basename(@srcdir)}>"
  end

  def noop(rel)
  end

  #
  # Hook Script API base methods
  #

  def srcdir_root
    @srcdir
  end

  def objdir_root
    @objdir
  end

  def relpath
    @currdir
  end

  #
  # Config Access
  #

  # module FileOperations requires this
  def verbose?
    @config.verbose?
  end

  # module FileOperations requires this
  def no_harm?
    @config.no_harm?
  end

  def verbose_off
    begin
      save, @config.verbose = @config.verbose?, false
      yield
    ensure
      @config.verbose = save
    end
  end

  #
  # TASK config
  #

  def exec_config
    exec_task_traverse 'config'
  end

  alias config_dir_bin noop
  alias config_dir_lib noop

  def config_dir_ext(rel)
    extconf if extdir?(curr_srcdir())
  end

  alias config_dir_data noop
  alias config_dir_conf noop
  alias config_dir_man noop

  def extconf
    ruby "#{curr_srcdir()}/extconf.rb", *@config.config_opt
  end

  #
  # TASK setup
  #

  def exec_setup
    exec_task_traverse 'setup'
  end

  def setup_dir_bin(rel)
    files_of(curr_srcdir()).each do |fname|
      update_shebang_line "#{curr_srcdir()}/#{fname}"
    end
  end

  alias setup_dir_lib noop

  def setup_dir_ext(rel)
    make if extdir?(curr_srcdir())
  end

  alias setup_dir_data noop
  alias setup_dir_conf noop
  alias setup_dir_man noop

  def update_shebang_line(path)
    return if no_harm?
    return if config('shebang') == 'never'
    old = Shebang.load(path)
    if old
      $stderr.puts "warning: #{path}: Shebang line includes too many args.  It is not portable and your program may not work." if old.args.size > 1
      new = new_shebang(old)
      return if new.to_s == old.to_s
    else
      return unless config('shebang') == 'all'
      new = Shebang.new(config('rubypath'))
    end
    $stderr.puts "updating shebang: #{File.basename(path)}" if verbose?
    open_atomic_writer(path) {|output|
      File.open(path, 'rb') {|f|
        f.gets if old   # discard
        output.puts new.to_s
        output.print f.read
      }
    }
  end

  def new_shebang(old)
    if /\Aruby/ =~ File.basename(old.cmd)
      Shebang.new(config('rubypath'), old.args)
    elsif File.basename(old.cmd) == 'env' and old.args.first == 'ruby'
      Shebang.new(config('rubypath'), old.args[1..-1])
    else
      return old unless config('shebang') == 'all'
      Shebang.new(config('rubypath'))
    end
  end

  def open_atomic_writer(path, &block)
    tmpfile = File.basename(path) + '.tmp'
    begin
      File.open(tmpfile, 'wb', &block)
      File.rename tmpfile, File.basename(path)
    ensure
      File.unlink tmpfile if File.exist?(tmpfile)
    end
  end

  class Shebang
    def Shebang.load(path)
      line = nil
      File.open(path) {|f|
        line = f.gets
      }
      return nil unless /\A#!/ =~ line
      parse(line)
    end

    def Shebang.parse(line)
      cmd, *args = *line.strip.sub(/\A\#!/, '').split(' ')
      new(cmd, args)
    end

    def initialize(cmd, args = [])
      @cmd = cmd
      @args = args
    end

    attr_reader :cmd
    attr_reader :args

    def to_s
      "#! #{@cmd}" + (@args.empty? ? '' : " #{@args.join(' ')}")
    end
  end

  #
  # TASK install
  #

  def exec_install
    rm_f 'InstalledFiles'
    exec_task_traverse 'install'
  end

  def install_dir_bin(rel)
    install_files targetfiles(), "#{config('bindir')}/#{rel}", 0755
  end

  def install_dir_lib(rel)
    install_files libfiles(), "#{config('rbdir')}/#{rel}", 0644
  end

  def install_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    install_files rubyextentions('.'),
                  "#{config('sodir')}/#{File.dirname(rel)}",
                  0555
  end

  def install_dir_data(rel)
    install_files targetfiles(), "#{config('datadir')}/#{rel}", 0644
  end

  def install_dir_conf(rel)
    # FIXME: should not remove current config files
    # (rename previous file to .old/.org)
    install_files targetfiles(), "#{config('sysconfdir')}/#{rel}", 0644
  end

  def install_dir_man(rel)
    install_files targetfiles(), "#{config('mandir')}/#{rel}", 0644
  end

  def install_files(list, dest, mode)
    mkdir_p dest, @config.install_prefix
    list.each do |fname|
      install fname, dest, mode, @config.install_prefix
    end
  end

  def libfiles
    glob_reject(%w(*.y *.output), targetfiles())
  end

  def rubyextentions(dir)
    ents = glob_select("*.#{@config.dllext}", targetfiles())
    if ents.empty?
      setup_rb_error "no ruby extention exists: 'ruby #{$0} setup' first"
    end
    ents
  end

  def targetfiles
    mapdir(existfiles() - hookfiles())
  end

  def mapdir(ents)
    ents.map {|ent|
      if File.exist?(ent)
      then ent                         # objdir
      else "#{curr_srcdir()}/#{ent}"   # srcdir
      end
    }
  end

  # picked up many entries from cvs-1.11.1/src/ignore.c
  JUNK_FILES = %w( 
    core RCSLOG tags TAGS .make.state
    .nse_depinfo #* .#* cvslog.* ,* .del-* *.olb
    *~ *.old *.bak *.BAK *.orig *.rej _$* *$

    *.org *.in .*
  )

  def existfiles
    glob_reject(JUNK_FILES, (files_of(curr_srcdir()) | files_of('.')))
  end

  def hookfiles
    %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
    }.flatten
  end

  def glob_select(pat, ents)
    re = globs2re([pat])
    ents.select {|ent| re =~ ent }
  end

  def glob_reject(pats, ents)
    re = globs2re(pats)
    ents.reject {|ent| re =~ ent }
  end

  GLOB2REGEX = {
    '.' => '\.',
    '$' => '\$',
    '#' => '\#',
    '*' => '.*'
  }

  def globs2re(pats)
    /\A(?:#{
      pats.map {|pat| pat.gsub(/[\.\$\#\*]/) {|ch| GLOB2REGEX[ch] } }.join('|')
    })\z/
  end

  #
  # TASK test
  #

  TESTDIR = 'test'

  def exec_test
    unless File.directory?('test')
      $stderr.puts 'no test in this package' if verbose?
      return
    end
    $stderr.puts 'Running tests...' if verbose?
    begin
      require 'test/unit'
    rescue LoadError
      setup_rb_error 'test/unit cannot loaded.  You need Ruby 1.8 or later to invoke this task.'
    end
    runner = Test::Unit::AutoRunner.new(true)
    runner.to_run << TESTDIR
    runner.run
  end

  #
  # TASK clean
  #

  def exec_clean
    exec_task_traverse 'clean'
    rm_f @config.savefile
    rm_f 'InstalledFiles'
  end

  alias clean_dir_bin noop
  alias clean_dir_lib noop
  alias clean_dir_data noop
  alias clean_dir_conf noop
  alias clean_dir_man noop

  def clean_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    make 'clean' if File.file?('Makefile')
  end

  #
  # TASK distclean
  #

  def exec_distclean
    exec_task_traverse 'distclean'
    rm_f @config.savefile
    rm_f 'InstalledFiles'
  end

  alias distclean_dir_bin noop
  alias distclean_dir_lib noop

  def distclean_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    make 'distclean' if File.file?('Makefile')
  end

  alias distclean_dir_data noop
  alias distclean_dir_conf noop
  alias distclean_dir_man noop

  #
  # Traversing
  #

  def exec_task_traverse(task)
    run_hook "pre-#{task}"
    FILETYPES.each do |type|
      if type == 'ext' and config('without-ext') == 'yes'
        $stderr.puts 'skipping ext/* by user option' if verbose?
        next
      end
      traverse task, type, "#{task}_dir_#{type}"
    end
    run_hook "post-#{task}"
  end

  def traverse(task, rel, mid)
    dive_into(rel) {
      run_hook "pre-#{task}"
      __send__ mid, rel.sub(%r[\A.*?(?:/|\z)], '')
      directories_of(curr_srcdir()).each do |d|
        traverse task, "#{rel}/#{d}", mid
      end
      run_hook "post-#{task}"
    }
  end

  def dive_into(rel)
    return unless File.dir?("#{@srcdir}/#{rel}")

    dir = File.basename(rel)
    Dir.mkdir dir unless File.dir?(dir)
    prevdir = Dir.pwd
    Dir.chdir dir
    $stderr.puts '---> ' + rel if verbose?
    @currdir = rel
    yield
    Dir.chdir prevdir
    $stderr.puts '<--- ' + rel if verbose?
    @currdir = File.dirname(rel)
  end

  def run_hook(id)
    path = [ "#{curr_srcdir()}/#{id}",
             "#{curr_srcdir()}/#{id}.rb" ].detect {|cand| File.file?(cand) }
    return unless path
    begin
      instance_eval File.read(path), path, 1
    rescue
      raise if $DEBUG
      setup_rb_error "hook #{path} failed:\n" + $!.message
    end
  end

end   # class Installer


class SetupError < StandardError; end

def setup_rb_error(msg)
  raise SetupError, msg
end

if $0 == __FILE__
  begin
    ToplevelInstaller.invoke
  rescue SetupError
    raise if $DEBUG
    $stderr.puts $!.message
    $stderr.puts "Try 'ruby #{$0} --help' for detailed usage."
    exit 1
  end
end
