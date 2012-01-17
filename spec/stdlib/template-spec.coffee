$ = require 'jquery'
Template = require 'template'

describe "Template", ->
  describe "toView", ->
    view = null

    beforeEach ->
      subviewTemplate = class extends Template
        content: (params) ->
          @div =>
            @h2 { outlet: "header" }, params.title
            @div "I am a subview"

      template = class extends Template
        content: (attrs) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, attrs.title
            @list()
            @subview 'subview', subviewTemplate.build(title: "Subview")

        list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        viewProperties:
          initialize: (attrs) ->
            @initializeCalledWith = attrs
          foo: "bar",
          li1Clicked: ->,
          li2Keypressed: ->
          viewClicked: ->

      view = template.build(title: "Zebra")

    describe ".build(attributes)", ->
      it "generates markup based on the content method", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "extends the view with viewProperties, calling the 'constructor' property if present", ->
        expect(view.constructor).toBeDefined()
        expect(view.foo).toBe("bar")
        expect(view.initializeCalledWith).toEqual title: "Zebra"

      it "wires references for elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector "li.foo:contains(one)"
        expect(view.li2).toMatchSelector "li.bar:contains(two)"

      it "constructs and wires outlets for subviews", ->
        expect(view.subview).toExist()
        expect(view.subview.find('h2:contains(Subview)')).toExist()

      it "does not overwrite outlets on the superview with outlets from the subviews", ->
        expect(view.header).toMatchSelector "h1"
        expect(view.subview.header).toMatchSelector "h2"

      it "binds events for elements with event name attributes", ->
        spyOn(view, 'viewClicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'keydown'
          expect(elt).toMatchSelector "div.rootDiv"

        spyOn(view, 'li1Clicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'click'
          expect(elt).toMatchSelector 'li.foo:contains(one)'

        spyOn(view, 'li2Keypressed').andCallFake (event, elt) ->
          expect(event.type).toBe 'keypress'
          expect(elt).toMatchSelector "li.bar:contains(two)"

        view.keydown()
        expect(view.viewClicked).toHaveBeenCalled()

        view.li1.click()
        expect(view.li1Clicked).toHaveBeenCalled()
        expect(view.li2Keypressed).not.toHaveBeenCalled()

        view.li1Clicked.reset()

        view.li2.keypress()
        expect(view.li2Keypressed).toHaveBeenCalled()
        expect(view.li1Clicked).not.toHaveBeenCalled()

      it "makes the original jquery wrapper accessible via the view method from any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

    describe "when a view is inserted within another element with jquery", ->
      [attachHandler, subviewAttachHandler] = []

      beforeEach ->
        attachHandler = jasmine.createSpy 'attachHandler'
        subviewAttachHandler = jasmine.createSpy 'subviewAttachHandler'
        view.on 'attach', attachHandler
        view.subview.on 'attach', subviewAttachHandler

      describe "when attached to an element that is on the DOM", ->
        it "triggers an 'attach' event on the view and its subviews", ->
          content = $('#jasmine-content')
          content.append view
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

          view.detach()
          content.empty()
          attachHandler.reset()
          subviewAttachHandler.reset()

          otherElt = $('<div>')
          content.append(otherElt)
          view.insertBefore(otherElt)
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

      describe "when attached to an element that is not on the DOM", ->
        it "does not trigger an attach event", ->
          fragment = $('<div>')
          fragment.append view
          expect(attachHandler).not.toHaveBeenCalled()

