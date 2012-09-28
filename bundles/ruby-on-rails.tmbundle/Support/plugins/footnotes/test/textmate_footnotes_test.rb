require 'test/unit'
require File.dirname(__FILE__) + '/../../../../config/environment'

require File.dirname(__FILE__) + '/../lib/textmate_footnotes'
require File.dirname(__FILE__) + '/mock_controller'

$html = DATA.read

class TextmateFootnotesTest < Test::Unit::TestCase
  def setup
    @controller = MockController.new $html.dup
    @footnote = FootnoteFilter.new(@controller)
  end

  def test_mock_controller
    index = @controller.response.body.index(/This is the HTML page/)
    assert_equal 334, index
  end

  def test_footnote_not_included_when_request_is_xhr
    @controller.request.xhr = true
    @footnote.add_footnotes!
    assert_equal $html, @controller.response.body
  end

  def test_footnote_not_included_when_content_type_is_javascript
    @controller.response.headers['Content-Type'] = 'text/javascript'
    @footnote.add_footnotes!
    assert_equal $html, @controller.response.body
  end

  def test_footnote_included_when_content_type_is_html
    @controller.response.headers['Content-Type'] = 'text/html'
    @footnote.add_footnotes!
    assert_not_equal $html, @controller.response.body
  end

  def test_footnote_included_when_content_type_is_nil
    @footnote.add_footnotes!
    assert_not_equal $html, @controller.response.body
  end

  def test_indent
    before = "text\n  one\n  two"
    after  = "  text\n    one\n    two"

    assert_equal after, @footnote.indent(2, before)

    before = " text\n  one\n  two"
    after  = "  text\n   one\n   two"

    assert_equal after, @footnote.indent(2, before)

    before = "  text\none\ntwo"
    after  = "  text\n  one\n  two"

    assert_equal after, @footnote.indent(2, before)
  end

  def test_insert_text
    @footnote.insert_text :after, /<head>/, "Graffiti", 0
    after = "    <head>Graffiti\n"
    assert_equal after, @footnote.body.to_a[2]

    @footnote.insert_text :before, /<\/body>/, "Notes", 0
    after = "    Notes</body>\n"
    assert_equal after, @footnote.body.to_a[12]
  end
end

__END__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
    <head>
        <title>HTML to XHTML Example: HTML page</title>
        <link rel="Stylesheet" href="htmltohxhtml.css" type="text/css" media="screen">
        <meta http-equiv="Content-Type" content="text/html;charset=UTF-8">
    </head>
    <body>
        <p>This is the HTML page. It works and is encoded just like any HTML page you
         have previously done. View <a href="htmltoxhtml2.htm">the XHTML version</a> of
         this page to view the difference between HTML and XHTML.</p>
        <p>You will be glad to know that no changes need to be made to any of your CSS files.</p>
    </body>
</html>