class Module
  remove_method :attr_reader
  def attr_reader(*names)
    names.each do |name|
      module_eval "def #{name}() @#{name} end"
    end
  end
  remove_method :attr_writer
  def attr_writer(*names)
    names.each do |name|
      module_eval "def #{name}=(x) @#{name}=x end"
    end
  end
  remove_method :attr_accessor
  def attr_accessor(*names)
    attr_reader(*names)
    attr_writer(*names)
  end
  remove_method :attr
  def attr(name, writer=false)
    attr_reader name
    attr_writer name if writer
  end
end


module MethodAnalyzer
  @@methods = Hash.new{ |h,k| h[k] = Hash.new{ |h,k| h[k] = []} }
  @@whereis = []
  @@expand_path = Hash.new{ |h,k| h[k] = File.expand_path(k)}
  
  def self.trace_func(event, file, line, id, binding, klass, *rest)
    return if file == __FILE__
    return if (event != 'call' and event != 'c-call')
    return if klass == Class and id == :inherited
    return if klass == Module and id == :method_added
    return if klass == Kernel and id == :singleton_method_added
    saved_crit = Thread.critical
    Thread.critical = true
    
    the_self = eval("self",binding)
    flag = Class === the_self ? "." : "#"
    #klass = klass == Kernel ? Object : klass
    fullname = "#{klass}#{flag}#{id}"
    file.replace @@expand_path[file]
    if event == 'call'
      @@whereis << [file, line, fullname] if file !~ /\(eval\)$/
      file, line, rest = caller(4)[0].split(/:/)
      file.replace @@expand_path[file] # DRY
      p caller(0) if $DEBUG
      line = line.to_i
    end
    @@methods[file][line] << fullname  if event =~ /call/

    Thread.critical = saved_crit
  end

  def self.at_exit__output_marshal
    at_exit do
      set_trace_func nil
      dbfile = "method_analysis"
      old = Marshal.load(File.read(dbfile)) rescue {}
      open(dbfile, "wb") do |io|
        # Because Marshal.dump cannot handle hashes with default_proc
        @@methods.default = nil
        @@methods.each_value{ |v| v.default=nil; v.each_value{ |vv| vv.uniq! } }
        Marshal.dump(@@methods.merge(old), io)
      end
    end
  end


  def self.at_exit__output_text
    at_exit do
      set_trace_func nil
      puts "method fullnames"
      @@methods.sort.each do |file, lines|
        lines.sort.each do |line, methods|
          printf "%s:%s:%s\n", file, line, methods.uniq.join(" ")
        end
      end

      puts
      puts "method definitions"
      @@whereis.sort.uniq.each do |file, line, fullname |
        printf "%s:%s:%s\n", file, line, fullname
      end

    end
  end

  def self.set_at_exit
    case ENV['METHOD_ANALYZER_FORMAT']
    when 'marshal'
      at_exit__output_marshal
    else
      at_exit__output_text
    end
  end

  set_at_exit
  set_trace_func method(:trace_func).to_proc
end

if __FILE__ == $0
  load "./test/data/method_analyzer-data.rb"
end
