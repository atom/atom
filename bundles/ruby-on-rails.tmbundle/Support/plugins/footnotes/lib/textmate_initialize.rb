class ActionController::Base
  attr_accessor :render_without_footnotes

  after_filter FootnoteFilter

protected
  alias footnotes_original_render render
  def render(options = nil, deprecated_status = nil, &block) #:doc:
    if options.is_a? Hash
      @render_without_footnotes = (options.delete(:footnotes) == false)
    end
    footnotes_original_render(options, deprecated_status, &block)
  end
end
