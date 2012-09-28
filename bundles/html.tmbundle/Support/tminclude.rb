# tminclude.rb
#
# An implementation of "Persistent Includes" for TextMate
# Brad Choate <brad@bradchoate.com> 

require 'singleton'

module TextMate
  class Includes
    include Singleton

    def initialize
      @time = Time.now
    end

    protected

    def reset
      @argument_regexp = Regexp.new(/\s*#([^#]+?)#\s*=\s*(?:(["'])([^\2]*?)\2|(\S+))\s*/m).freeze
      @depth = 1
      @ctime = nil
      @mtime = nil

      init_comment_delimiters()
      init_global_vars()
    end

    def init_comment_delimiters
      if ENV['TM_COMMENT_START']
        @escape_open = (ENV['TM_COMMENT_START'].dup.strip).freeze
        @escape_close = (ENV['TM_COMMENT_END'] ? ENV['TM_COMMENT_END'].dup.strip : '').freeze
      else
        @escape_open = '<!--'.freeze
        @escape_close = '-->'.freeze
      end

      # non-capturing for .gsub
      # <!-- #tminclude "/path/to/file" -->
      # <!-- #tminclude "/path/to/file" #arg#="value" ... -->
      if ENV['TM_COMMENT_END']
        escaped_open = Regexp.escape(@escape_open)
        escaped_close = Regexp.escape(@escape_close)
        @tminclude_regexp = %r{#{escaped_open}\s*#(?:tm|bb)include\s.*?#{escaped_close}.+?#{escaped_open}\s*end (?:tm|bb)include\s*#{escaped_close}}im
        # version that captures for .scan
        @tminclude_regexp_detail = %r{(#{escaped_open}\s*#(?:tm|bb)include\s+['"]([^'"]+)['"](?:\s+(.*?))?#{escaped_close})(.+?)(#{escaped_open}\s*end (?:tm|bb)include\s*#{escaped_close})}im
      else
        escaped_open = Regexp.escape(@escape_open)
        @tminclude_regexp = %r{#{escaped_open} *#(?:tm|bb)include [^\n]*?\n.*?#{escaped_open} +end (?:tm|bb)include *(\n|$)}im
        # version that captures for .scan
        @tminclude_regexp_detail = %r{(#{escaped_open} *#(?:tm|bb)include +['"]([^'"]+)['"](?: +([^\n]*?))?)(\n.*?)(#{escaped_open} +end (?:tm|bb)include *(?:\n|$))}im
      end
    end

    def init_global_vars
      @global_vars = {}
      # start by setting all the TM_* defined variables
      ENV.each_pair do | k, v |
        if k =~ /^TM_(.+)/
          @global_vars[$1.downcase] = v
        end
      end
      # Here are some of BBEdit's global variables. We may choose
      # to cherry pick these for support...
      @global_vars['dont_update'] = ''
      @global_vars['shortusername'] = ENV['USER']
      # lazily invoke this one, since it has cost associated with it...
      @global_vars['username'] = method("var_username")

      @global_vars['localtime'] = method("var_localtime")
      @global_vars['gmtime'] = method("var_gmtime")
      @global_vars['longdate'] = @time.strftime("%A, %B %e, %Y").sub(/  /, ' ')
      @global_vars['compdate'] = @time.strftime("%d-%b-%y")
      @global_vars['monthnum'] = @time.strftime("%m")
      @global_vars['monthdaynum'] = @time.strftime("%d")
      @global_vars['shortdate'] = @time.strftime("%m/%d/%y").gsub(/0(\d\/)/, '\1')
      @global_vars['abbrevdate'] = @time.strftime("%a, %b %e, %Y").sub(/  /, ' ')
      @global_vars['yearnum'] = @time.year
      @global_vars['generator'] = "TextMate"

      init_file_vars(ENV['TM_FILEPATH'])

      if ENV['TM_PROJECT_FILEPATH']
        dir = ENV['TM_PROJECT_FILEPATH'].dup
        fdir = ENV['TM_DIRECTORY'].dup
        dir.sub!(/\/[^\/]+$/, '')
        dir = Regexp.quote(dir)
        fdir.sub!(Regexp.new("^" + dir), '')
        fdir.sub!(/^\//, '')
        fdir.sub!(/\/$/, '')
        paths = fdir.split(/\//)
        @global_vars['relative'] = ("../" * paths.length) || ""
      end

      # Web Project settings
      # Site Name (Local Web)
      # Web Server Name (http://localhost/)
      # Site Path on Server (/path/to/site)
      # Default Page Name (index.html)
      # Local Site Root (~/path/to/site)
      # Template/Include path (~/path:~/path)
      # Local Preview URL

      # Unsupported...
      # base, base_url, charset, dirpath, doctitle, language,
      # link, machine, meta, path, prefix, real_url, root,
      # rootpath, server, title
    end

    def init_file_vars(file)
      @global_vars['localpath'] = file
      basename = File.basename(file)
      @global_vars['filename'] = basename
      @global_vars['basename'] = basename.sub(/\.\w+$/, '')
      @global_vars['file_extension'] = File.extname(file)

      if ctime = File.ctime(file)
        @ctime = ctime
        @global_vars['creationdate'] = method('var_creationdate')
        @global_vars['creationtime'] = method('var_creationtime')
      end
      if mtime = File.mtime(file)
        @mtime = mtime
        @global_vars['modifieddate'] = method('var_modifieddate')
        @global_vars['modifiedtime'] = method('var_modifiedtime')
      end
    end

    def parse_arguments(arg_str, vars)
      arg_str.scan(@argument_regexp) do | var, quote, val, val2 |
        vars[var.downcase] = val.nil? ? val2 : val
      end
    end

    def replace_variables(content, vars)
      content.gsub(/(#\w+(?:\s+[^#]+?)?#)/m) do | expr |
        # normalize variable... strip '#' prefix/suffix/parameter, downcase
        var = expr.gsub(/^\#|\#$/, '')
        if var =~ / +(.+)/
          attribute = $1
          var.sub!(/ .+/, '')
        else
          attribute = nil
        end
        var.downcase!
        out = vars[var] || @global_vars[var] || expr
        if out.kind_of?(Method)
          case out.arity
            when 0
              out.call
            when 1
              out.call(attribute)
            when -1
              attribute.nil? ? out.call : out.call(attribute)
            else
              expr
          end
        else
          out
        end
      end
    end

    def invoke_interpreter(file, vars)
      require "#{ENV['TM_SUPPORT_PATH']}/lib/escape.rb"
      # run interpreter using file and requested arguments
      filepath = e_sh(ENV['TM_FILEPATH'] || '/dev/null')
      argstr = ''
      vars.each_pair { | k, v | argstr << " " << e_sh(k) << " " << e_sh(v) }
      %x{#{e_sh file} #{filepath}#{argstr}};
    end

    def process_include(file, args, vars)
      @doc_stack ||= Hash.new

      local_vars = vars.dup
      @depth += 1

      content = nil

      # File resolution; expand ~/... paths;
      # look for relative files, relative to current file, current project, replace variables
      file = replace_variables(file, local_vars)
      file_dir = File.dirname(ENV['TM_FILEPATH'])
      if File.exist?(filepath = File.expand_path(file))
      elsif file.match(/^\//) # non-relative path...
        raise Exception, "Could not find file: #{file}"
      elsif File.exist?(filepath = "#{file_dir}/#{file}")
      else
        raise Exception, "Could not find file: #{file}"
      end

      file = filepath

      if @doc_stack.has_key?(file)
        raise Exception, "Error: recursive include for #{file}"
      end

      @doc_stack[file] = true

      parse_arguments(args, local_vars) unless args.nil?
      if File.executable?(file) and file.match(/\.(pl|rb|py)$/)
        content = invoke_interpreter(file, local_vars)
      else
        content = IO.readlines(file).join
      end
      replace_variables(content, local_vars)
      if content.scan(@tminclude_regexp)
        content = process_document(content, local_vars)
      end

      @doc_stack.delete(file)

      @depth -= 1
      content
    end

    # Dynamic variables

    def var_creationtime(format = "%l:%M %p")
      @ctime ? @ctime.strftime(format) : nil
    end

    def var_creationdate(format = "%d-%b-%y")
      @ctime ? @ctime.strftime(format) : nil
    end

    def var_modifiedtime(format = "%l:%M %p")
      @mtime ? @mtime.strftime(format) : nil
    end

    def var_modifieddate(format = "%d-%b-%y")
      @mtime ? @mtime.strftime(format) : nil
    end

    def var_localtime(format = "%c")
      @time.strftime(format)
    end

    def var_gmtime(format = "%c")
      @time.gmtime.strftime(format)
    end

    def var_username
      # store the username into the variable stash so we don't have
      # to do this again...
      @global_vars['username'] = ENV['TM_FULLNAME']
    end

    def process_document(doc, vars)
      # process blocks that look like this:
      # <!-- #tminclude "/path/to/file" -->
      # <!-- end tminclude -->
      # and this...
      # <!-- #tminclude "/path/to/file" #param#="value" #param2#="value" -->
      # <!-- end tminclude -->
      doc.gsub!(@tminclude_regexp) do | match |
        result = match
        match.scan(@tminclude_regexp_detail) do | open, file, args, incl, close |
          if @depth == 1
            result = "#{open}\n#{process_include(file, args, vars)}\n#{close}"
          else
            result = "#{process_include(file, args, vars)}"
          end
        end
        result
      end
      replace_variables(doc, vars)
    end

    def process_persistent_includes_for_string(doc)
      vars = {}
      process_document(doc, vars)

      # lastly, process '#docsize#'
      # TBD: support for reporting document size in kb, mb, etc.
      # TBD: support for image sizes as well.
      matches = doc.scan(/#docsize#/i)
      if matches.length
        # baselen is document without any "#docsize#" elements
        baselen = doc.length - '#docsize#'.length * matches.length
        # newlen is document with added docsize values
        newlen = baselen + baselen.to_s.length * matches.length
        # sometimes this adjustment causes the length of the document
        # to change again, so check for that.
        while baselen + (newlen.to_s.length * matches.length) != newlen
          newlen = baselen + (newlen.to_s.length * matches.length)
        end
        doc.gsub!(/#docsize#/i, newlen.to_s)
      end
    end

    public

    def process_persistent_includes_for_project
      require "#{ENV['TM_SUPPORT_PATH']}/lib/textmate.rb"
      count = 0
      begin
        TextMate.each_text_file do | file |
          doc = IO.readlines(file).join
          if doc.match(/#(tm|bb)include/)
            if not doc.match(/#dont_update#/)
              ENV['TM_FILEPATH'] = file
              ENV['TM_DIRECTORY'] = File.dirname(file)
              reset
              newdoc = doc.dup
              process_persistent_includes_for_string(newdoc)
              if newdoc != doc
                if File.writable?(file)
                  f = File.new(file, "w")
                  f.write(newdoc)
                  f.close
                  count += 1
                end
              end
            end
          end
        end
      rescue Exception => e
        print e
        exit 206
      end
      if count == 1
        print "1 file updated"
        TextMate.rescan_project
      elsif count > 1
        print "#{count} files updated"
        TextMate.rescan_project
      else
        print "No files needed an update"
      end
      exit 206
    end

    def process_persistent_includes
      #initialize
      reset

      doc = STDIN.readlines.join
      if doc =~ /\#dont_update\#/
        print "This document cannot be updated because it is protected."
        exit 206
      end
      begin
        process_persistent_includes_for_string(doc)
      rescue Exception => e
        print e
        exit 206
      end
      print doc
    end

    def include_command
      #initialize
      init_comment_delimiters()

      require "#{ENV['TM_SUPPORT_PATH']}/lib/ui.rb"
      cstart = (@escape_open).rstrip + ' '
      cend = (' ' + @escape_close).rstrip
      begin
        TextMate::UI.request_file do | file |
          print <<-"EOT"
#{cstart}#tminclude "#{file}"#{cend}
#{cstart}end tminclude#{cend}
EOT
        end
      rescue SystemExit
        exit 200
      end
    end
  end
end
