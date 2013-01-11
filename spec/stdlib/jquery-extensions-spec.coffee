$ = require 'jquery'
{View, $$} = require 'space-pen'

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

  describe "$.fn.events() and $.fn.document", ->
    it "returns a list of all events being listened for on the target node or its ancestors, along with their documentation string", ->
      view = $$ ->
        @div id: 'a', =>
          @div id: 'b', =>
            @div id: 'c'
          @div id: 'd'

      view.document
        'a1': "This is event A2"
        'b2': "This is event b2"

      view.document 'a1': "A1: Waste perfectly-good steak"
      view.on 'a1', ->
      view.on 'a2', ->
      view.on 'b1', -> # should not appear as a duplicate

      divB = view.find('#b')

      divB.document
        'b1': "B1: Super-sonic bomber"
        'b2': "B2: Looks evil. Kinda is."
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
