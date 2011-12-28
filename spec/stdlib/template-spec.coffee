Template = require 'template'

fdescribe "Template", ->
  describe "toView", ->
    Foo = null
    view = null

    beforeEach ->
      class Foo extends Template
        content: (attrs) ->
          @div =>
            @h1 attrs.title
            @list()

        list: ->
          @ol =>
            @li outlet: 'li1', class: 'foo', "one"
            @li outlet: 'li2', class: 'bar', "two"

      view = Foo.build(title: "Zebra")

    afterEach ->
      delete window.Foo

    describe ".build(attributes)", ->
      it "generates markup based on the content method", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "wires references for elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector("li.foo:contains(one)")
        expect(view.li2).toMatchSelector("li.bar:contains(two)")

