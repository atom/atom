CommandRegistry = require '../src/command-registry'

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
    atom.commands.restoreDOMEventMethods()
    registry.patchDOMEventMethods()

  afterEach ->
    registry.restoreDOMEventMethods()
    atom.commands.patchDOMEventMethods()
    registry.destroy()

  describe "when a command event is dispatched on an element", ->
    it "invokes callbacks with selectors matching the target", ->
      called = false
      registry.listen '.grandchild', 'command', (event) ->
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

      registry.listen '.child', 'command', (event) ->
        expect(this).toBe child
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe child
        calls.push('child')

      registry.listen '.parent', 'command', (event) ->
        expect(this).toBe parent
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe parent
        calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child', 'parent']

    it "invokes inline listeners prior to listeners applied via selectors", ->
      calls = []
      registry.listen '.grandchild', 'command', -> calls.push('grandchild')
      registry.listen child, 'command', -> calls.push('child-inline')
      registry.listen '.child', 'command', -> calls.push('child')
      registry.listen '.parent', 'command', -> calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['grandchild', 'child-inline', 'child', 'parent']

    it "orders multiple matching listeners for an element by selector specificity", ->
      child.classList.add('foo', 'bar')
      calls = []

      registry.listen '.foo.bar', 'command', -> calls.push('.foo.bar')
      registry.listen '.foo', 'command', -> calls.push('.foo')
      registry.listen '.bar', 'command', -> calls.push('.bar') # specificity ties favor commands added later, like CSS

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['.foo.bar', '.bar', '.foo']

    it "does not bubble the event if the ::bubbles property is false on the dispatched event", ->
      calls = []

      registry.listen '.grandchild', 'command', -> calls.push('grandchild')
      registry.listen '.child', 'command', -> calls.push('child')
      registry.listen '.parent', 'command', -> calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: false))
      expect(calls).toEqual ['grandchild']

    it "invokes capture-phase listeners before bubble-phase listeners", ->
      calls = []

      # Spot-check event details for both capture and bubbling phase
      registry.capture '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.CAPTURING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        calls.push('grandchild-capture')

      registry.listen '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        calls.push('grandchild-bubble')

      registry.capture child, 'command', -> calls.push('child-inline-capture')
      registry.listen child, 'command', -> calls.push('child-inline-bubble')
      registry.capture '.child', 'command', -> calls.push('child-capture')
      registry.capture '.parent', 'command', -> calls.push('parent-capture')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['parent-capture', 'child-inline-capture', 'child-capture', 'grandchild-capture', 'grandchild-bubble', 'child-inline-bubble']

    it "stops bubbling through ancestors when .stopPropagation() is called on the event", ->
      calls = []

      registry.listen '.parent', 'command', -> calls.push('parent')
      registry.listen '.child', 'command', -> calls.push('child-2')
      registry.listen '.child', 'command', (event) -> calls.push('child-1'); event.stopPropagation()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'stopPropagation')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(calls).toEqual ['child-1', 'child-2']

    it "stops invoking callbacks when .stopImmediatePropagation() is called on the event", ->
      calls = []

      registry.listen '.parent', 'command', -> calls.push('parent')
      registry.listen '.child', 'command', -> calls.push('child-2')
      registry.listen '.child', 'command', (event) -> calls.push('child-1'); event.stopImmediatePropagation()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'stopImmediatePropagation')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(calls).toEqual ['child-1']

    it "forwards .preventDefault() calls from the synthetic event to the original", ->
      registry.listen '.child', 'command', (event) -> event.preventDefault()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      spyOn(dispatchedEvent, 'preventDefault')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(dispatchedEvent.preventDefault).toHaveBeenCalled()

    it "forwards .abortKeyBinding() calls from the synthetic event to the original", ->
      registry.listen '.child', 'command', (event) -> event.abortKeyBinding()

      dispatchedEvent = new CustomEvent('command', bubbles: true)
      dispatchedEvent.abortKeyBinding = jasmine.createSpy('abortKeyBinding')
      grandchild.dispatchEvent(dispatchedEvent)
      expect(dispatchedEvent.abortKeyBinding).toHaveBeenCalled()

    it "allows listeners to be removed via a disposable returned by ::add", ->
      calls = []

      disposable1 = registry.listen '.parent', 'command', -> calls.push('parent')
      disposable2 = registry.listen '.child', 'command', -> calls.push('child')

      disposable1.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child']

      calls = []
      disposable2.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual []

    it "allows multiple commands to be registered under one selector when called with an object", ->
      calls = []

      disposable = registry.listen '.child',
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

  describe "::findCommands({target})", ->
    it "returns commands that can be invoked on the target or its ancestors", ->
      registry.listen '.parent', 'namespace:command-1', ->
      registry.listen '.child', 'namespace:command-2', ->
      registry.listen '.grandchild', 'namespace:command-3', ->
      registry.listen '.grandchild.no-match', 'namespace:command-4', ->

      expect(registry.findCommands(target: grandchild)[0..2]).toEqual [
        {name: 'namespace:command-3', displayName: 'Namespace: Command 3'}
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

  describe "::dispatch(target, commandName)", ->
    it "simulates invocation of the given command ", ->
      called = false
      registry.listen '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        called = true

      registry.dispatch(grandchild, 'command')
      expect(called).toBe true

    it "returns a boolean indicating whether any listeners matched the command", ->
      registry.listen '.grandchild', 'command', ->

      expect(registry.dispatch(grandchild, 'command')).toBe true
      expect(registry.dispatch(grandchild, 'bogus')).toBe false
      expect(registry.dispatch(parent, 'command')).toBe false

    it "does not perform bubbling for native event names that should not bubble", ->
      calls = []

      registry.listen '.grandchild', 'focus', -> calls.push('grandchild')
      registry.listen '.child', 'focus', -> calls.push('child')
      registry.listen '.parent', 'focus', -> calls.push('parent')

      registry.dispatch(grandchild, 'focus')
      expect(calls).toEqual ['grandchild']

    it "allows an event object to be passed instead of an event name", ->
      called = false
      registry.listen '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        expect(event.detail).toEqual {a: 1}
        called = true

      registry.dispatch(grandchild, new CustomEvent('command', bubbles: true), {a: 1})
      expect(called).toBe true

  describe "::getSnapshot and ::restoreSnapshot", ->
    it "removes all command handlers except for those in the snapshot", ->
      registry.listen '.parent', 'namespace:command-1', ->
      registry.listen '.child', 'namespace:command-2', ->
      snapshot = registry.getSnapshot()
      registry.listen '.grandchild', 'namespace:command-3', ->

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

      registry.listen '.grandchild', 'namespace:command-3', ->
      registry.restoreSnapshot(snapshot)

      expect(registry.findCommands(target: grandchild)[0..1]).toEqual [
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

  describe "::addEventListener and ::removeEventListener overrides", ->
    it "mixes listeners registered via ::addEventListener with selector-based listeners", ->
      calls = []
      registry.listen '.grandchild', 'command', -> calls.push('grandchild')
      registry.listen '.child', 'command', -> calls.push('child')
      registry.listen '.parent', 'command', -> calls.push('parent')

      bubbleListener = -> calls.push('child-inline-bubble')
      captureListener = -> calls.push('child-inline-capture')
      child.addEventListener('command', bubbleListener)
      child.addEventListener('command', captureListener, true)

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child-inline-capture', 'grandchild', 'child-inline-bubble', 'child', 'parent']

      child.removeEventListener('command', bubbleListener)
      child.removeEventListener('command', captureListener, true)

      calls = []
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['grandchild', 'child', 'parent']

    it "invokes handlers on detached DOM nodes", ->
      detachedNode = document.createElement('div')
      called = false
      detachedNode.addEventListener 'command', -> called = true
      detachedNode.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(called).toBe true
