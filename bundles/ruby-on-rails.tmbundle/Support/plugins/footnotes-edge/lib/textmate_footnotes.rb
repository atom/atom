class String
  def line_from_index(index)
    lines = self.to_a
    running_length = 0
    lines.each_with_index do |line, i|
      running_length += line.length
      if running_length > index
        return i
      end
    end
  end
end

class FootnoteFilter
  cattr_accessor :no_style, :abs_root, :textmate_prefix
  self.no_style = false
  self.textmate_prefix = "txmt://open?url=file://"

  attr_accessor :body, :abs_root

  def self.filter(controller)
    return if controller.render_without_footnotes
    filter = FootnoteFilter.new(controller)
    filter.add_footnotes!
  end

  def initialize(controller)
    @controller = controller
    @template = controller.instance_variable_get("@template")
    @body = controller.response.body
    @extra_html = ""
    self.abs_root = File.expand_path(RAILS_ROOT)
  end

  def add_footnotes!
    if performed_render? and first_render?
      if ["html.erb", "haml", "rhtml", "rxhtml"].include?(template_extension) && (content_type =~ /html/ || content_type.nil?) && !xhr?
        # If the user would like to be responsible for the styles, let them opt out of the styling here
        insert_styles unless FootnoteFilter.no_style
        insert_footnotes
      end
    end
  rescue Exception => e
    # Discard footnotes if there are any problems
    RAILS_DEFAULT_LOGGER.error "Textmate Footnotes Exception: #{e}\n#{e.backtrace.join("\n")}"
  end

  # Some controller classes come with the Controller:: module and some don't
  # (anyone know why? -- Duane)
  def controller_filename
    File.join(abs_root, "app", "controllers", "#{@controller.class.to_s.underscore}.rb").
    sub('/controllers/controllers/', '/controllers/')
  end

  def controller_text
    @controller_text ||= IO.read(controller_filename)
  end

  def index_of_method
    (controller_text =~ /def\s+#{@controller.action_name}[\s\(]/)
  end

  def controller_line_number
    controller_text.line_from_index(index_of_method)
  end

  def performed_render?
    @controller.instance_variable_get("@performed_render")
  end

  def first_render?
    @template.respond_to?(:first_render) and @template.first_render
  end

  def xhr?
    @controller.request.xhr?
  end

  def template_path
    @template.first_render.sub(/\.(html\.erb|rhtml|rxhtml|rxml|rjs)$/, "")
  end

  def template_extension
    @template.first_render.scan(/\.(html\.erb|rhtml|rxhtml|rxml|rjs)$/).flatten.first ||
    @template.pick_template_extension(template_path).to_s
  end

  def template_file_name
    File.expand_path(@template.send(:full_template_path, template_path, template_extension))
  end

  def layout_file_name
    ["html.erb", "rhtml"].each do |extension|
      path = File.expand_path(@template.send(:full_template_path, @controller.active_layout, extension))
      return path if File.exist?(path)
    end
  end

  def content_type
    @controller.response.headers['Content-Type']
  end

  def stylesheet_files
    @stylesheet_files ||= @body.scan(/<link[^>]+href\s*=\s*['"]([^>?'"]+)/im).flatten
  end

  def javascript_files
    @javascript_files ||= @body.scan(/<script[^>]+src\s*=\s*['"]([^>?'"]+)/im).flatten
  end

  def controller_url
    escape(
      textmate_prefix +
      controller_filename +
      (index_of_method ? "&line=#{controller_line_number + 1}&column=3" : "")
    )
  end

  def view_url
    escape(textmate_prefix + template_file_name)
  end

  def layout_url
    escape(textmate_prefix + layout_file_name)
  end

  def insert_styles
    insert_text :before, /<\/head>/i, <<-HTML
    <!-- TextMate Footnotes Style -->
    <style type="text/css">
      #tm_footnotes_debug {margin-top: 0.5em; text-align: center; color: #999;}
      #tm_footnotes_debug a {text-decoration: none; color: #bbb;}
      #tm_footnotes_debug pre {overflow: scroll;}
      fieldset.tm_footnotes_debug_info {text-align: left; border: 1px dashed #aaa; padding: 1em; margin: 1em 2em 1em 2em; color: #777;}
    </style>
    <!-- End TextMate Footnotes Style -->
    HTML
  end

  def insert_footnotes

    def tm_footnotes_toggle(id)
      "s = document.getElementById('#{id}').style; if(s.display == 'none') { s.display = '' } else { s.display = 'none' }"
    end

    footnotes_html = <<-HTML
    <!-- TextMate Footnotes -->
    <div style="clear:both"></div>
    <div id="tm_footnotes_debug">
      #{textmate_links}
      Show:
      <a href="#" onclick="#{tm_footnotes_toggle('session_debug_info')};return false">Session</a> |
      <a href="#" onclick="#{tm_footnotes_toggle('cookies_debug_info')};return false">Cookies</a> |
      <a href="#" onclick="#{tm_footnotes_toggle('params_debug_info')};return false">Params</a> |
      <a href="#" onclick="#{tm_footnotes_toggle('general_debug_info')};return false">General Debug</a>
      <br/>(<a href="http://blog.inquirylabs.com/2006/09/28/textmate-footnotes-v16-released/"><b>TextMate Footnotes</b></a>)
      #{@extra_html}
      <fieldset id="session_debug_info" class="tm_footnotes_debug_info" style="display: none">
        <legend>Session</legend>
        #{escape(@controller.session.instance_variable_get("@data").inspect)}
      </fieldset>
      <fieldset id="cookies_debug_info" class="tm_footnotes_debug_info" style="display: none">
        <legend>Cookies</legend>
        <code>#{escape(@controller.send(:cookies).inspect)}</code>
      </fieldset>
      <fieldset id="params_debug_info" class="tm_footnotes_debug_info" style="display: none">
        <legend>Params</legend>
        <code>#{escape(@controller.params.inspect)}</code>
      </fieldset>
      <fieldset id="general_debug_info" class="tm_footnotes_debug_info" style="display: none">
        <legend>General (id="tm_debug")</legend>
        <div id="tm_debug"></div>
      </fieldset>
    </div>
    <!-- End TextMate Footnotes -->
    HTML
    if @body =~ %r{<div[^>]+id=['"]tm_footnotes['"][^>]*>}
      # Insert inside the "tm_footnotes" div if it exists
      insert_text :after, %r{<div[^>]+id=['"]tm_footnotes['"][^>]*>}, footnotes_html
    else
      # Otherwise, try to insert as the last part of the html body
      insert_text :before, /<\/body>/i, footnotes_html
    end
  end

  def textmate_links
    html = ""
    if ::MAC_OS_X
      html = <<-HTML
        Edit:
        <a href="#{controller_url}">Controller</a> |
        <a href="#{view_url}">View</a> |
        <a href="#{layout_url}">Layout</a>
      HTML
      html += asset_file_links("Stylesheets", stylesheet_files) unless stylesheet_files.blank?
      html += asset_file_links("Javascripts", javascript_files) unless javascript_files.blank?
      html += "<br/>"
    end
    html
  end

  def asset_file_links(link_text, files)
    return '' if files.size == 0
    links = files.map do |filename|
      if filename =~ %r{^/}
        full_filename = File.join(abs_root, "public", filename)
        %{<a href="#{textmate_prefix}#{full_filename}">#{filename}</a>}
      else
        %{<a href="#{filename}">#{filename}</a>}
      end
    end
    @extra_html << <<-HTML
      <fieldset id="tm_footnotes_#{link_text.underscore.gsub(' ', '_')}" class="tm_footnotes_debug_info" style="display: none">
        <legend>#{link_text}</legend>
        <ul><li>#{links.join("</li><li>")}</li></ul>
      </fieldset>
    HTML
    # Return the link that will open the 'extra html' div
    %{ | <a href="#" onclick="#{tm_footnotes_toggle('tm_footnotes_' + link_text.underscore.gsub(' ', '_') )}; return false">#{link_text}</a>}
  end

  def indent(indentation, text)
    lines = text.to_a
    initial_indentation = lines.first.scan(/^(\s+)/).flatten.first
    lines.map do |line|
      if initial_indentation.nil?
        " " * indentation + line
      elsif line.index(initial_indentation) == 0
        " " * indentation + line[initial_indentation.size..-1]
      else
        " " * indentation + line
      end
    end.join
  end

  # Inserts text in to the body of the document
  # +pattern+ is a Regular expression which, when matched, will cause +new_text+
  # to be inserted before or after the match.  If no match is found, +new_text+ is appended
  # to the body instead. +position+ may be either :before or :after
  def insert_text(position, pattern, new_text, indentation = 4)
    index = case pattern
      when Regexp
        if match = @body.match(pattern)
          match.offset(0)[position == :before ? 0 : 1]
        else
          @body.size
        end
      else
        pattern
      end
    @body.insert index, indent(indentation, new_text)
  end

  def escape(text)
    text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
end