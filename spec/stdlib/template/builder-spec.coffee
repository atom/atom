Builder = require 'template/builder'

fdescribe "Builder", ->
  builder = null

  beforeEach -> builder = new Builder

  describe ".toFragment()", ->
    it "creates outlet references on the fragment for elements with an outlet", ->
      builder.tag 'div', ->
        builder.tag 'div', id: 'foo', outlet: 'a'
        builder.tag 'div', id: 'bar', outlet: 'b'

      fragment = builder.toFragment()
      expect(fragment.a).toMatchSelector '#foo'
      expect(fragment.b).toMatchSelector '#bar'

  describe ".tag(name, args...)", ->
    it "can generate simple tags", ->
      builder.tag 'div'
      expect(builder.toHtml()).toBe("<div></div>")

      builder.reset()
      builder.tag 'ol'
      expect(builder.toHtml()).toBe("<ol></ol>")

    it "can generate tags with content", ->
      builder.tag 'ol', ->
        builder.tag 'li'
        builder.tag 'li'

      expect(builder.toHtml()).toBe("<ol><li></li><li></li></ol>")

    it "can generate tags with text", ->
      builder.tag 'div', "hello"
      expect(builder.toHtml()).toBe("<div>hello</div>")

      builder.reset()
      builder.tag 'div', 22
      expect(builder.toHtml()).toBe("<div>22</div>")

    it "can generate tags with attributes", ->
      builder.tag 'div', id: 'foo', class: 'bar'
      fragment = builder.toFragment()
      expect(fragment.attr('id')).toBe('foo')
      expect(fragment.attr('class')).toBe('bar')

    it "can generate self-closing tags", ->
      builder.tag 'br', id: 'foo'
      expect(builder.toHtml()).toBe('<br id="foo">')

