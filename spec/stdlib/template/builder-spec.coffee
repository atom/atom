Builder = require 'template/builder'
Template = require 'template'

describe "Builder", ->
  builder = null

  beforeEach -> builder = new Builder

  describe ".tag(name, args...)", ->
    it "can generate simple tags", ->
      builder.tag 'div'
      expect(builder.toHtml()).toBe "<div></div>"

      builder.reset()
      builder.tag 'ol'
      expect(builder.toHtml()).toBe "<ol></ol>"

    it "can generate tags with content", ->
      builder.tag 'ol', ->
        builder.tag 'li'
        builder.tag 'li'

      expect(builder.toHtml()).toBe "<ol><li></li><li></li></ol>"

    it "can generate tags with text", ->
      builder.tag 'div', "hello"
      expect(builder.toHtml()).toBe "<div>hello</div>"

      builder.reset()
      builder.tag 'div', 22
      expect(builder.toHtml()).toBe "<div>22</div>"

    it "can generate tags with attributes", ->
      builder.tag 'div', id: 'foo', class: 'bar'
      fragment = builder.toFragment()
      expect(fragment.attr('id')).toBe 'foo'
      expect(fragment.attr('class')).toBe 'bar'

    it "can generate self-closing tags", ->
      builder.tag 'br', id: 'foo'
      expect(builder.toHtml()).toBe '<br id="foo">'

  describe ".subview(name, template, attrs)", ->
    template = null

    beforeEach ->
      template = class extends Template
        content: (params) ->
          @div =>
            @h2 params.title
            @div "I am a subview"

    it "inserts a view built from the given template with the given params", ->
      builder.tag 'div', ->
        builder.tag 'h1', "Superview"
        builder.subview 'sub', template, title: "Subview"

      fragment = builder.toFragment()
      expect(fragment.find("h1:contains(Superview)")).toExist()
      expect(fragment.find("h2:contains(Subview)")).toExist()
      subview = fragment.find('div[outlet=sub]')
      expect(subview).toMatchSelector ':has(h2):contains(I am a subview)'

