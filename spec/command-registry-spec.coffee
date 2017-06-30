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
    registry.attach(parent)

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

    it "orders inline listeners by reverse registration order", ->
      calls = []
      registry.add child, 'command', -> calls.push('child1')
      registry.add child, 'command', -> calls.push('child2')
      child.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child2', 'child1']

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

    it "copies non-standard properties from the original event to the synthetic event", ->
      syntheticEvent = null
      registry.add '.child', 'command', (event) -> syntheticEvent = event

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      dispatchedEvent.nonStandardProperty = 'testing'
      grandchild.dispatchEvent(dispatchedEvent)
      expect(syntheticEvent.nonStandardProperty).toBe 'testing'

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

    it "invokes callbacks registered with ::onWillDispatch and ::onDidDispatch and ::onDidFinish", ->
      sequence = []

      registry.onDidFinish (event) ->
        sequence.push ['onDidFinish', event]

      registry.onDidDispatch (event) ->
        sequence.push ['onDidDispatch', event]

      registry.add '.grandchild', 'command', (event) ->
        sequence.push ['listener', event]

      registry.onWillDispatch (event) ->
        sequence.push ['onWillDispatch', event]

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))

      expect(sequence[0][0]).toBe 'onWillDispatch'
      expect(sequence[1][0]).toBe 'listener'
      expect(sequence[2][0]).toBe 'onDidDispatch'

      waitsFor ( -> sequence.length is 4 ), "onDidFinish never called"

      runs ->
        expect(sequence[3][0]).toBe 'onDidFinish'

        expect(sequence[0][1] is sequence[1][1] is sequence[2][1] is sequence[3][1]).toBe true
        expect(sequence[0][1].constructor).toBe CustomEvent
        expect(sequence[0][1].target).toBe grandchild

    it "invokes callbacks registered with ::onDidFinish on resolve", ->
      sequence = []

      registry.onDidFinish (event) ->
        sequence.push ['onDidFinish', event]

      registry.add '.grandchild', 'command', (event) ->
        sequence.push ['listener', event]
        new Promise (resolve) ->
          setTimeout ( ->
            sequence.push ['resolve', event]
            resolve()
          ), 100

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      advanceClock 100

      waitsFor ( -> sequence.length is 3 ), "onDidFinish never called for resolve"

      runs ->
        expect(sequence[0][0]).toBe 'listener'
        expect(sequence[1][0]).toBe 'resolve'
        expect(sequence[2][0]).toBe 'onDidFinish'

        expect(sequence[0][1] is sequence[1][1] is sequence[2][1]).toBe true
        expect(sequence[0][1].constructor).toBe CustomEvent
        expect(sequence[0][1].target).toBe grandchild

    it "invokes callbacks registered with ::onDidFinish on reject", ->
      sequence = []

      registry.onDidFinish (event) ->
        sequence.push ['onDidFinish', event]

      registry.add '.grandchild', 'command', (event) ->
        sequence.push ['listener', event]
        new Promise (_, reject) ->
          setTimeout ( ->
            sequence.push ['reject', event]
            reject()
          ), 100

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      advanceClock 100

      waitsFor ( -> sequence.length is 3 ), "onDidFinish never called for reject"

      runs ->
        expect(sequence[0][0]).toBe 'listener'
        expect(sequence[1][0]).toBe 'reject'
        expect(sequence[2][0]).toBe 'onDidFinish'

        expect(sequence[0][1] is sequence[1][1] is sequence[2][1]).toBe true
        expect(sequence[0][1].constructor).toBe CustomEvent
        expect(sequence[0][1].target).toBe grandchild

  describe "::add(selector, commandName, callback)", ->
    it "throws an error when called with an invalid selector", ->
      badSelector = '<>'
      addError = null
      try
        registry.add badSelector, 'foo:bar', ->
      catch error
        addError = error
      expect(addError.message).toContain(badSelector)

    it "throws an error when called with a non-function callback and selector target", ->
      badCallback = null
      addError = null

      try
        registry.add '.selector', 'foo:bar', badCallback
      catch error
        addError = error
      expect(addError.message).toContain("Can't register a command with non-function callback.")

    it "throws an error when called with an non-function callback and object target", ->
      badCallback = null
      addError = null

      try
        registry.add document.body, 'foo:bar', badCallback
      catch error
        addError = error
      expect(addError.message).toContain("Can't register a command with non-function callback.")

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

  describe "::attach(rootNode)", ->
    it "adds event listeners for any previously-added commands", ->
      registry2 = new CommandRegistry

      commandSpy = jasmine.createSpy('command-callback')
      registry2.add '.grandchild', 'command-1', commandSpy

      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      expect(commandSpy).not.toHaveBeenCalled()

      registry2.attach(parent)

      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      expect(commandSpy).toHaveBeenCalled()
