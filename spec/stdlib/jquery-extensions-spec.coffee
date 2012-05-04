$ = require 'jquery'

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
