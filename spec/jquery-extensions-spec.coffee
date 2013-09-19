{_, $, $$, View} = require 'atom'

describe 'jQuery extensions', ->
  describe '$.fn.preempt(eventName, handler)', ->
    [returnValue, element, events] = []

    beforeEach ->
      returnValue = undefined
      element = $("<div>")
      events = []

      element.on 'foo', -> events.push(1)
      element.preempt 'foo', ->
        events.push(2)
        returnValue
      element.on 'foo', -> events.push(3)

    it 'calls the preempting handler before all others', ->
      element.trigger 'foo'
      expect(events).toEqual [2,1,3]

    describe 'when handler returns false', ->
      it 'does not call subsequent handlers', ->
        returnValue = false
        element.trigger 'foo'
        expect(events).toEqual [2]

    describe 'when the event is namespaced', ->
      it 'calls handler', ->
        element.preempt 'foo.bar', -> events.push(4)
        element.trigger 'foo'
        expect(events).toEqual [4,2,1,3]

        events = []
        element.trigger 'foo.bar'
        expect(events).toEqual [4]

        events = []
        element.off('.bar')
        element.trigger 'foo'
        expect(events).toEqual [2,1,3]

  describe "$.fn.events() and $.fn.document(...)", ->
    it "returns a list of all events being listened for on the target node or its ancestors, along with their documentation string", ->
      view = $$ ->
        @div id: 'a', =>
          @div id: 'b', =>
            @div id: 'c'
          @div id: 'd'

      view.document 'a1', "This is event A2"
      view.document 'b2', "This is event b2"

      view.document 'a1', "A1: Waste perfectly-good steak"
      view.on 'a1', ->
      view.on 'a2', ->
      view.on 'b1', -> # should not appear as a duplicate

      divB = view.find('#b')

      divB.document 'b1', "B1: Super-sonic bomber"
      divB.document 'b2', "B2: Looks evil. Kinda is."
      divB.on 'b1', ->
      divB.on 'b2', ->

      view.find('#c').on 'c', ->
      view.find('#d').on 'd', ->

      expect(view.find('#c').events()).toEqual
        'c': null
        'b1': "B1: Super-sonic bomber"
        'b2': "B2: Looks evil. Kinda is."
        'a1': "A1: Waste perfectly-good steak"
        'a2': null

  describe "$.fn.command(eventName, [selector, options,] handler)", ->
    [view, handler] = []

    beforeEach ->
      view = $$ ->
        @div class: 'a', =>
          @div class: 'b'
          @div class: 'c'
      handler = jasmine.createSpy("commandHandler")

    it "binds the handler to the given event / selector for all argument combinations", ->
      view.command 'test:foo', handler
      view.trigger 'test:foo'
      expect(handler).toHaveBeenCalled()
      handler.reset()

      view.command 'test:bar', '.b', handler
      view.find('.b').trigger 'test:bar'
      view.find('.c').trigger 'test:bar'
      expect(handler.callCount).toBe 1
      handler.reset()

      view.command 'test:baz', doc: 'Spaz', handler
      view.trigger 'test:baz'
      expect(handler).toHaveBeenCalled()
      handler.reset()

      view.command 'test:quux', '.c', doc: 'Lorem', handler
      view.find('.b').trigger 'test:quux'
      view.find('.c').trigger 'test:quux'
      expect(handler.callCount).toBe 1

    it "passes the 'data' option through when binding the event handler", ->
      view.command 'test:foo', data: "bar", handler
      view.trigger 'test:foo'
      expect(handler.argsForCall[0][0].data).toBe 'bar'

    it "sets a custom docstring if the 'doc' option is specified", ->
      view.command 'test:foo', doc: "Foo!", handler
      expect(view.events()).toEqual 'test:foo': 'Test: Foo!'

    it "capitalizes the 'github' prefix how we like it", ->
      view.command 'github:spelling', handler
      expect(view.events()).toEqual 'github:spelling': 'GitHub: Spelling'

  describe "$.fn.scrollUp/Down/ToTop/ToBottom", ->
    it "scrolls the element in the specified way if possible", ->
      view = $$ -> @div => _.times 20, => @div('A')
      view.css(height: 100, width: 100, overflow: 'scroll')
      view.attachToDom()

      view.scrollUp()
      expect(view.scrollTop()).toBe 0

      view.scrollDown()
      expect(view.scrollTop()).toBeGreaterThan 0
      previousScrollTop = view.scrollTop()
      view.scrollDown()
      expect(view.scrollTop()).toBeGreaterThan previousScrollTop

      view.scrollToBottom()
      expect(view.scrollTop()).toBe view.prop('scrollHeight') - 100
      previousScrollTop = view.scrollTop()
      view.scrollDown()
      expect(view.scrollTop()).toBe previousScrollTop
      view.scrollUp()
      expect(view.scrollTop()).toBeLessThan previousScrollTop
      previousScrollTop = view.scrollTop()
      view.scrollUp()
      expect(view.scrollTop()).toBeLessThan previousScrollTop

      view.scrollToTop()
      expect(view.scrollTop()).toBe 0

  describe "Event.prototype", ->
    class GrandchildView extends View
      @content: -> @div class: 'grandchild'

    class ChildView extends View
      @content: ->
        @div class: 'child', =>
          @subview 'grandchild', new GrandchildView

    class ParentView extends View
      @content: ->
        @div class: 'parent', =>
          @subview 'child', new ChildView

    [parentView, event] = []
    beforeEach ->
      parentView = new ParentView
      eventHandler = jasmine.createSpy('eventHandler')
      parentView.on 'foo', '.child', eventHandler
      parentView.child.grandchild.trigger 'foo'
      event = eventHandler.argsForCall[0][0]

    describe ".currentTargetView()", ->
      it "returns the current target's space pen view", ->
        expect(event.currentTargetView()).toBe parentView.child

    describe ".targetView()", ->
      it "returns the target's space pen view", ->
        expect(event.targetView()).toBe parentView.child.grandchild
