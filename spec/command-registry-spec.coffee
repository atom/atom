CommandRegistry = require '../src/command-registry'
_ = require 'underscore-plus'

describe "CommandRegistry", ->
  [registry, parent, child, grandchild] = []

  beforeEach ->
    parent = document.createElement("div")
    child = document.createElement("div")
    grandchild = document.createElement("div")
    parent.classList.add('parent')
    child.classList.add('child')
    grandchild.classList.add('grandchild')
    child.appendChild(grandchild)
    parent.appendChild(child)
    document.querySelector('#jasmine-content').appendChild(parent)

    registry = new CommandRegistry

  afterEach ->
    registry.destroy()

  describe "when a command event is dispatched on an element", ->
    it "invokes callbacks with selectors matching the target", ->
      called = false
      registry.add '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        called = true

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(called).toBe true

    it "invokes callbacks with selectors matching ancestors of the target", ->
      calls = []

      registry.add '.child', 'command', (event) ->
        expect(this).toBe child
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe child
        calls.push('child')

      registry.add '.parent', 'command', (event) ->
        expect(this).toBe parent
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe parent
        calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child', 'parent']

    it "invokes inline listeners prior to listeners applied via selectors", ->
      calls = []
      registry.add '.grandchild', 'command', -> calls.push('grandchild')
      registry.add child, 'command', -> calls.push('child-inline')
      registry.add '.child', 'command', -> calls.push('child')
      registry.add '.parent', 'command', -> calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['grandchild', 'child-inline', 'child', 'parent']

    it "orders multiple matching listeners for an element by selector specificity", ->
      child.classList.add('foo', 'bar')
      calls = []

      registry.add '.foo.bar', 'command', -> calls.push('.foo.bar')
      registry.add '.foo', 'command', -> calls.push('.foo')
      registry.add '.bar', 'command', -> calls.push('.bar') # specificity ties favor commands added later, like CSS

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['.foo.bar', '.bar', '.foo']

    it "stops bubbling through ancestors when .stopPropagation() is called on the event", ->
      calls = []

      registry.add '.parent', 'command', -> calls.push('parent')
      registry.add '.child', 'command', -> calls.push('child-2')
      registry.add '.child', 'command', (event) -> calls.push('child-1'); event.stopPropagation()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'stopPropagation')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(calls).toEqual ['child-1', 'child-2']
      expect(dispatchedEvent.stopPropagation).toHaveBeenCalled()

    it "stops invoking callbacks when .stopImmediatePropagation() is called on the event", ->
      calls = []

      registry.add '.parent', 'command', -> calls.push('parent')
      registry.add '.child', 'command', -> calls.push('child-2')
      registry.add '.child', 'command', (event) -> calls.push('child-1'); event.stopImmediatePropagation()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'stopImmediatePropagation')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(calls).toEqual ['child-1']
      expect(dispatchedEvent.stopImmediatePropagation).toHaveBeenCalled()

    it "forwards .preventDefault() calls from the synthetic event to the original", ->
      registry.add '.child', 'command', (event) -> event.preventDefault()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'preventDefault')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(dispatchedEvent.preventDefault).toHaveBeenCalled()

    it "forwards .abortKeyBinding() calls from the synthetic event to the original", ->
      registry.add '.child', 'command', (event) -> event.abortKeyBinding()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      dispatchedEvent.abortKeyBinding = jasmine.createSpy('abortKeyBinding')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(dispatchedEvent.abortKeyBinding).toHaveBeenCalled()

    it "allows listeners to be removed via a disposable returned by ::add", ->
      calls = []

      disposable1 = registry.add '.parent', 'command', -> calls.push('parent')
      disposable2 = registry.add '.child', 'command', -> calls.push('child')

      disposable1.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child']

      calls = []
      disposable2.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual []

    it "allows multiple commands to be registered under one selector when called with an object", ->
      calls = []

      disposable = registry.add '.child',
        'command-1': -> calls.push('command-1')
        'command-2': -> calls.push('command-2')

      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      grandchild.dispatchEvent(new CustomEvent('command-2', bubbles: true))

      expect(calls).toEqual ['command-1', 'command-2']

      calls = []
      disposable.dispose()
      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      grandchild.dispatchEvent(new CustomEvent('command-2', bubbles: true))
      expect(calls).toEqual []

  describe "::add(selector, commandName, callback)", ->
    it "throws an error when called with an invalid selector", ->
      badSelector = '<>'
      addError = null
      try
        registry.add badSelector, 'foo:bar', ->
      catch error
        addError = error
      expect(addError.message).toContain(badSelector)

  describe "::findCommands({target})", ->
    it "returns commands that can be invoked on the target or its ancestors", ->
      registry.add '.parent', 'namespace:command-1', ->
      registry.add '.child', 'namespace:command-2', ->
      registry.add '.grandchild', 'namespace:command-3', ->
      registry.add '.grandchild.no-match', 'namespace:command-4', ->

      registry.add grandchild, 'namespace:inline-command-1', ->
      registry.add child, 'namespace:inline-command-2', ->

      commands = registry.findCommands(target: grandchild)
      nonJqueryCommands = _.reject commands, (cmd) -> cmd.jQuery
      expect(nonJqueryCommands).toEqual [
        {name: 'namespace:inline-command-1', displayName: 'Namespace: Inline Command 1'}
        {name: 'namespace:command-3', displayName: 'Namespace: Command 3'}
        {name: 'namespace:inline-command-2', displayName: 'Namespace: Inline Command 2'}
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

  describe "::dispatch(target, commandName)", ->
    it "simulates invocation of the given command ", ->
      called = false
      registry.add '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        called = true

      registry.dispatch(grandchild, 'command')
      expect(called).toBe true

    it "returns a boolean indicating whether any listeners matched the command", ->
      registry.add '.grandchild', 'command', ->

      expect(registry.dispatch(grandchild, 'command')).toBe true
      expect(registry.dispatch(grandchild, 'bogus')).toBe false
      expect(registry.dispatch(parent, 'command')).toBe false

  describe "::getSnapshot and ::restoreSnapshot", ->
    it "removes all command handlers except for those in the snapshot", ->
      registry.add '.parent', 'namespace:command-1', ->
      registry.add '.child', 'namespace:command-2', ->
      snapshot = registry.getSnapshot()
      registry.add '.grandchild', 'namespace:command-3', ->

      expect(registry.findCommands(target: grandchild)[0..2]).toEqual [
        {name: 'namespace:command-3', displayName: 'Namespace: Command 3'}
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

      registry.restoreSnapshot(snapshot)

      expect(registry.findCommands(target: grandchild)[0..1]).toEqual [
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

      registry.add '.grandchild', 'namespace:command-3', ->
      registry.restoreSnapshot(snapshot)

      expect(registry.findCommands(target: grandchild)[0..1]).toEqual [
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]
