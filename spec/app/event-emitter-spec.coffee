_ = require 'underscore'
EventEmitter = require 'event-emitter'

describe "EventEmitter mixin", ->
  [object, fooHandler1, fooHandler2, barHandler] = []

  beforeEach ->
    object = {}
    _.extend(object, EventEmitter)

    fooHandler1 = jasmine.createSpy('fooHandler1')
    fooHandler2 = jasmine.createSpy('fooHandler2')
    barHandler = jasmine.createSpy('barHandler')

    object.on 'foo', fooHandler1
    object.on 'foo', fooHandler2
    object.on 'bar', barHandler

  describe ".on", ->
    describe "when called with multiple space-separated event names", ->
      it "subscribes to each event names", ->
        object.on '    a.b  c.d\te ', fooHandler1

        object.trigger 'a'
        expect(fooHandler1).toHaveBeenCalled()

        fooHandler1.reset()
        object.trigger 'c'
        expect(fooHandler1).toHaveBeenCalled()

        fooHandler1.reset()
        object.trigger 'e'
        expect(fooHandler1).toHaveBeenCalled()

        fooHandler1.reset()
        object.trigger ''
        expect(fooHandler1).not.toHaveBeenCalled()

  describe ".trigger", ->
    describe "when called with a non-namespaced event name", ->
      it "triggers all handlers registered for the given event name", ->
        object.trigger 'foo', 'data'
        expect(fooHandler1).toHaveBeenCalledWith('data')
        expect(fooHandler2).toHaveBeenCalledWith('data')
        expect(barHandler).not.toHaveBeenCalled()

        fooHandler1.reset()
        fooHandler2.reset()

        object.trigger 'bar', 'stuff'
        expect(barHandler).toHaveBeenCalledWith('stuff')

    describe "when there are namespaced handlers", ->
      it "triggers only handlers registered with the given namespace / event combination", ->
        barHandler2 = jasmine.createSpy('barHandler2')
        object.on('bar.ns1', barHandler2)

        object.trigger('bar')

        expect(barHandler).toHaveBeenCalled()
        expect(barHandler2).toHaveBeenCalled()
        barHandler.reset()
        barHandler2.reset()

        object.trigger('bar.ns1')

        expect(barHandler).not.toHaveBeenCalled()
        expect(barHandler2).toHaveBeenCalled()

    it "does not raise exceptions when called with non-existent events / namespaces", ->
      object.trigger('junk')
      object.trigger('junk.garbage')

  describe ".off", ->
    describe "when called with no arguments", ->
      it "removes all subscriptions", ->
        object.off()
        object.trigger 'foo'
        expect(fooHandler1).not.toHaveBeenCalled()
        expect(fooHandler2).not.toHaveBeenCalled()

    describe "when called with multiple space-separated event names", ->
      it "unsubscribes from each event name", ->
        object.on 'a.b c.d e', fooHandler1
        object.off ' a.b\te   '

        object.trigger 'a'
        expect(fooHandler1).not.toHaveBeenCalled()

        fooHandler1.reset()
        object.trigger 'e'
        expect(fooHandler1).not.toHaveBeenCalled()

        fooHandler1.reset()
        object.trigger 'c.d'
        expect(fooHandler1).toHaveBeenCalled()

    describe "when called with a non-namespaced event name", ->
      it "removes all handlers for that event name", ->
        object.off 'foo'
        object.trigger 'foo'
        expect(fooHandler1).not.toHaveBeenCalled()
        expect(fooHandler2).not.toHaveBeenCalled()

    describe "when called with a non-namespaced event name and a handler function", ->
      it "removes the specific handler", ->
        object.off 'foo', fooHandler1
        object.trigger 'foo'
        expect(fooHandler1).not.toHaveBeenCalled()
        expect(fooHandler2).toHaveBeenCalled()

      it "does not throw an exception if there was not matching `on` call", ->
        expect(-> object.off 'marco', -> "nothing").not.toThrow()

    describe "when there are namespaced event handlers", ->
      [barHandler2, bazHandler1, bazHandler2, bazHandler3] = []

      beforeEach ->
        barHandler2 = jasmine.createSpy('barHandler2')
        bazHandler1 = jasmine.createSpy('bazHandler1')
        bazHandler2 = jasmine.createSpy('bazHandler2')
        bazHandler3 = jasmine.createSpy('bazHandler3')

        object.on 'bar.ns1', barHandler2
        object.on 'baz.ns1', bazHandler1
        object.on 'baz.ns1', bazHandler2
        object.on 'baz.ns2', bazHandler3

      describe "when called with a namespaced event name", ->
        it "removes all handlers in that namespace", ->
          object.trigger 'baz'

          expect(bazHandler1).toHaveBeenCalled()
          expect(bazHandler2).toHaveBeenCalled()
          expect(bazHandler3).toHaveBeenCalled()

          bazHandler1.reset()
          bazHandler2.reset()
          bazHandler3.reset()

          object.off 'baz.ns1'
          object.trigger 'baz'
          object.trigger 'baz.ns1'

          expect(bazHandler1).not.toHaveBeenCalled()
          expect(bazHandler2).not.toHaveBeenCalled()
          expect(bazHandler3).toHaveBeenCalled()

      describe "when called with just a namespace", ->
        it "removes all handlers for all events on that namespace", ->
          object.trigger 'bar'
          expect(barHandler).toHaveBeenCalled()
          expect(barHandler2).toHaveBeenCalled()

          barHandler.reset()
          barHandler2.reset()

          object.trigger 'baz'
          expect(bazHandler1).toHaveBeenCalled()
          expect(bazHandler2).toHaveBeenCalled()
          expect(bazHandler3).toHaveBeenCalled()

          bazHandler1.reset()
          bazHandler2.reset()
          bazHandler3.reset()

          object.off '.ns1'

          object.trigger 'bar'
          object.trigger 'bar.ns1'
          expect(barHandler).toHaveBeenCalled()
          expect(barHandler2).not.toHaveBeenCalled()

          object.trigger 'baz'
          object.trigger 'baz.ns1'

          expect(bazHandler1).not.toHaveBeenCalled()
          expect(bazHandler2).not.toHaveBeenCalled()
          expect(bazHandler3).toHaveBeenCalled()

        describe "when called with event names and namespaces that don't exist", ->
          it "does not raise an exception", ->
            object.off 'junk'
            object.off '.garbage'
            object.off 'junk.garbage'


  describe ".one(event, callback)", ->
    it "triggers the given callback once, then removes the subscription", ->
      oneHandler = jasmine.createSpy('oneHandler')
      object.one 'event', oneHandler

      object.trigger('event')
      expect(oneHandler).toHaveBeenCalled()
      oneHandler.reset()

      object.trigger('event')
      expect(oneHandler).not.toHaveBeenCalled()

  describe ".subscriptionCount()", ->
    it "returns the total number of subscriptions on the object", ->
      expect(object.subscriptionCount()).toBe 3

      object.on 'baz', ->
      expect(object.subscriptionCount()).toBe 4

      object.off 'foo'
      expect(object.subscriptionCount()).toBe 2
