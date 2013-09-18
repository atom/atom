Subscriber = require '../src/subscriber'
EventEmitter = require '../src/event-emitter'
{_, $$} = require 'atom-api'

describe "Subscriber", ->
  [emitter1, emitter2, emitter3, event1Handler, event2Handler, event3Handler, subscriber] = []

  class TestEventEmitter
  _.extend TestEventEmitter.prototype, EventEmitter

  class TestSubscriber
  _.extend TestSubscriber.prototype, Subscriber

  beforeEach ->
    emitter1 = new TestEventEmitter
    emitter2 = new TestEventEmitter
    emitter3 = $$ ->
      @div =>
        @a()
        @span()
    subscriber = new TestSubscriber
    event1Handler = jasmine.createSpy("event1Handler")
    event2Handler = jasmine.createSpy("event2Handler")
    event3Handler = jasmine.createSpy("event3Handler")
    subscriber.subscribe emitter1, 'event1', event1Handler
    subscriber.subscribe emitter2, 'event2', event2Handler
    subscriber.subscribe emitter3, 'event3', 'a', event3Handler

  it "subscribes to events on the specified object", ->
    emitter1.trigger 'event1', 'foo'
    expect(event1Handler).toHaveBeenCalledWith('foo')

    emitter2.trigger 'event2', 'bar'
    expect(event2Handler).toHaveBeenCalledWith('bar')

    emitter3.find('span').trigger 'event3'
    expect(event3Handler).not.toHaveBeenCalledWith()

    emitter3.find('a').trigger 'event3'
    expect(event3Handler).toHaveBeenCalled()

  it "allows an object to unsubscribe en-masse", ->
    subscriber.unsubscribe()
    emitter1.trigger 'event1', 'foo'
    emitter2.trigger 'event2', 'bar'
    expect(event1Handler).not.toHaveBeenCalled()
    expect(event2Handler).not.toHaveBeenCalled()

  it "allows an object to unsubscribe from a specific object", ->
    subscriber.unsubscribe(emitter1)
    emitter1.trigger 'event1', 'foo'
    emitter2.trigger 'event2', 'bar'
    expect(event1Handler).not.toHaveBeenCalled()
    expect(event2Handler).toHaveBeenCalledWith('bar')
