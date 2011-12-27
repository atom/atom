Builder = require 'template/builder'

fdescribe "Builder", ->
  builder = null

  beforeEach -> builder = new Builder

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

