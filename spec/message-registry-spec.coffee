MessageRegistry = require '../src/message-registry'

describe 'MessageRegistry', ->
  [registry] = []

  beforeEach ->
    registry = new MessageRegistry

  describe '::add', ->
    it 'throws an error when the listener is not a function', ->
      badAdder = -> registry.add 'package:message', 'not a function'
      expect(badAdder).toThrow()

    describe 'the returned disosable', ->
      it 'removes the callback', ->
        spy = jasmine.createSpy('callback')
        disposable = registry.add 'package:message', spy
        disposable.dispose()
        registry.dispatch 'atom://atom/package:message'
        expect(spy).not.toHaveBeenCalled()

      it 'removes only the associated callback', ->
        spy1 = jasmine.createSpy('callback 1')
        spy2 = jasmine.createSpy('callback 2')
        registry.add 'package:message', spy1
        disposable = registry.add 'package:message', spy2
        disposable.dispose()
        registry.dispatch 'atom://atom/package:message'
        expect(spy1).toHaveBeenCalledWith('package:message', {})
        expect(spy2).not.toHaveBeenCalledWith('package:message', {})

      it 'removes all callbacks when created via ::add(object)', ->
        spy1 = jasmine.createSpy('callback 1')
        spy2 = jasmine.createSpy('callback 2')
        disposable = registry.add
          'package:message1': spy1
          'package:message2': spy2
        disposable.dispose()
        registry.dispatch 'atom://atom/package:message1'
        registry.dispatch 'atom://atom/package:message2'
        expect(spy1).not.toHaveBeenCalled()
        expect(spy2).not.toHaveBeenCalled()

  describe '::dispatch', ->
    describe 'when a single callback is registered', ->
      [spy1, spy2] = []

      beforeEach ->
        spy1 = jasmine.createSpy('callback1 ')
        spy2 = jasmine.createSpy('callback 2')

      it 'invokes callbacks for matching messages', ->
        registry.add 'package:message', spy1
        registry.add 'package:other-message', spy2
        registry.dispatch 'atom://atom/package:message'
        expect(spy1).toHaveBeenCalledWith 'package:message', {}
        expect(spy2).not.toHaveBeenCalled()

    describe 'when multiple callbacks are registered', ->
      [spy1, spy2, spy3] = []

      beforeEach ->
        spy1 = jasmine.createSpy('callback 1')
        spy2 = jasmine.createSpy('callback 2')
        spy3 = jasmine.createSpy('callback 3')

      it 'invokes all the registered callbacks for matching messages', ->
        registry.add 'package:message', spy1
        registry.add 'package:message', spy2
        registry.add 'package:other-message', spy3
        registry.dispatch 'atom://atom/package:message'
        expect(spy1).toHaveBeenCalledWith('package:message', {})
        expect(spy2).toHaveBeenCalledWith('package:message', {})
        expect(spy3).not.toHaveBeenCalled()

    describe 'when a message with params is dispatched', ->
      it 'invokes the callback with the given params', ->
        spy = jasmine.createSpy('callback')
        registry.add 'package:message', spy
        registry.dispatch 'atom://atom/package:message?one=1&2=two'
        expectedParams =
          one: '1'
          2: 'two'
        expect(spy).toHaveBeenCalledWith('package:message', expectedParams)
