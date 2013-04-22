Subscriber = require 'subscriber'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

describe "Subscriber", ->
  [emitter1, emitter2, event1Handler, event2Handler, subscriber] = []

  class TestEventEmitter
  _.extend TestEventEmitter.prototype, EventEmitter

  class TestSubscriber
  _.extend TestSubscriber.prototype, Subscriber

  beforeEach ->
    emitter1 = new TestEventEmitter
    emitter2 = new TestEventEmitter
    subscriber = new TestSubscriber
    event1Handler = jasmine.createSpy("event1Handler")
    event2Handler = jasmine.createSpy("event2Handler")
    subscriber.subscribe emitter1, 'event1', event1Handler
    subscriber.subscribe emitter2, 'event2', event2Handler

  it "subscribes to events on the specified object", ->
    emitter1.trigger 'event1', 'foo'
    expect(event1Handler).toHaveBeenCalledWith('foo')

    emitter2.trigger 'event2', 'bar'
    expect(event2Handler).toHaveBeenCalledWith('bar')

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
