GlobalKeymap = require 'global-keymap'
$ = require 'jquery'

describe "GlobalKeymap", ->
  fragment = null
  keymap = null

  beforeEach ->
    keymap = new GlobalKeymap
    fragment = $ """
      <div class="command-mode">
        <div class="child-node">
          <div class="grandchild-node"/>
        </div>
      </div>
    """

  describe ".handleKeyEvent(event)", ->
    deleteCharHandler = null
    insertCharHandler = null

    beforeEach ->
      keymap.bindKeys '.command-mode', 'x': 'deleteChar'
      keymap.bindKeys '.insert-mode', 'x': 'insertChar'

      deleteCharHandler = jasmine.createSpy 'deleteCharHandler'
      insertCharHandler = jasmine.createSpy 'insertCharHandler'
      fragment.on 'deleteChar', deleteCharHandler
      fragment.on 'insertChar', insertCharHandler

    it "adds a 'keystroke' string to the event object", ->
      event = keydownEvent('x', altKey: true, metaKey: true)
      keymap.handleKeyEvent(event)
      expect(event.keystroke).toBe 'alt-meta-x'

    describe "when no binding matches the event", ->
      it "returns true, so the event continues to propagate", ->
        expect(keymap.handleKeyEvent(keydownEvent('0', target: fragment[0]))).toBeTruthy()

    describe "when the event's target node matches a selector with a matching binding", ->
      it "triggers the command event associated with that binding on the target node and returns false", ->
        result = keymap.handleKeyEvent(keydownEvent('x', target: fragment[0]))
        expect(result).toBe(false)
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        event = keydownEvent('x', target: fragment[0])
        keymap.handleKeyEvent(event)
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()
        commandEvent = insertCharHandler.argsForCall[0][0]
        expect(commandEvent.keyEvent).toBe event
        expect(event.keystroke).toBe 'x'

    describe "when the event's target node *descends* from a selector with a matching binding", ->
      it "triggers the command event associated with that binding on the target node and returns false", ->
        target = fragment.find('.child-node')[0]
        result = keymap.handleKeyEvent(keydownEvent('x', target: target))
        expect(result).toBe(false)
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        keymap.handleKeyEvent(keydownEvent('x', target: target))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

    describe "when the event's target node descends from multiple nodes that match selectors with a binding", ->
      it "only triggers bindings on selectors associated with the closest ancestor node", ->
        keymap.bindKeys '.child-node', 'x': 'foo'
        fooHandler = jasmine.createSpy 'fooHandler'
        fragment.on 'foo', fooHandler

        target = fragment.find('.grandchild-node')[0]
        keymap.handleKeyEvent(keydownEvent('x', target: target))
        expect(fooHandler).toHaveBeenCalled()
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

    describe "when the event bubbles to a node that matches multiple selectors", ->
      describe "when the matching selectors differ in specificity", ->
        it "triggers the binding for the most specific selector", ->
          keymap.bindKeys 'div .child-node', 'x': 'foo'
          keymap.bindKeys '.command-mode .child-node', 'x': 'baz'
          keymap.bindKeys '.child-node', 'x': 'bar'

          fooHandler = jasmine.createSpy 'fooHandler'
          barHandler = jasmine.createSpy 'barHandler'
          bazHandler = jasmine.createSpy 'bazHandler'
          fragment.on 'foo', fooHandler
          fragment.on 'bar', barHandler
          fragment.on 'baz', bazHandler

          target = fragment.find('.grandchild-node')[0]
          keymap.handleKeyEvent(keydownEvent('x', target: target))

          expect(fooHandler).not.toHaveBeenCalled()
          expect(barHandler).not.toHaveBeenCalled()
          expect(bazHandler).toHaveBeenCalled()

      describe "when the matching selectors have the same specificity", ->
        it "triggers the bindings for the most recently declared selector", ->
          keymap.bindKeys '.child-node', 'x': 'foo', 'y': 'baz'
          keymap.bindKeys '.child-node', 'x': 'bar'

          fooHandler = jasmine.createSpy 'fooHandler'
          barHandler = jasmine.createSpy 'barHandler'
          bazHandler = jasmine.createSpy 'bazHandler'
          fragment.on 'foo', fooHandler
          fragment.on 'bar', barHandler
          fragment.on 'baz', bazHandler

          target = fragment.find('.grandchild-node')[0]
          keymap.handleKeyEvent(keydownEvent('x', target: target))

          expect(barHandler).toHaveBeenCalled()
          expect(fooHandler).not.toHaveBeenCalled()

          keymap.handleKeyEvent(keydownEvent('y', target: target))
          expect(bazHandler).toHaveBeenCalled()

  describe ".bindKeys(selector, fnOrMap)", ->
    describe "when called with a function", ->
      it "calls the given function when selector matches", ->
        handler = jasmine.createSpy 'handler'
        keymap.bindKeys '.child-node', handler

        target = fragment.find('.grandchild-node')[0]
        event = keydownEvent('y', target: target)
        keymap.handleKeyEvent event

        expect(handler).toHaveBeenCalledWith(event)

      describe "when the function returns a command string", ->
        it "triggers the command event on the target and stops propagating the event", ->
          keymap.bindKeys '*', 'x': 'foo'
          keymap.bindKeys '*', -> 'bar'
          fooHandler = jasmine.createSpy('fooHandler')
          barHandler = jasmine.createSpy('barHandler')
          fragment.on 'foo', fooHandler
          fragment.on 'bar', barHandler

          target = fragment.find('.child-node')[0]
          keymap.handleKeyEvent(keydownEvent('x', target: target))

          expect(fooHandler).not.toHaveBeenCalled()
          expect(barHandler).toHaveBeenCalled()

      describe "when the function returns false", ->
        it "stops propagating the event", ->
          keymap.bindKeys '*', 'x': 'foo'
          keymap.bindKeys '*', -> false
          fooHandler = jasmine.createSpy('fooHandler')
          fragment.on 'foo', fooHandler

          target = fragment.find('.child-node')[0]
          keymap.handleKeyEvent(keydownEvent('x', target: target))

          expect(fooHandler).not.toHaveBeenCalled()

      describe "when the function returns anything other than a string or false", ->
        it "continues to propagate the event", ->
          keymap.bindKeys '*', 'x': 'foo'
          keymap.bindKeys '*', -> undefined
          fooHandler = jasmine.createSpy('fooHandler')
          fragment.on 'foo', fooHandler

          target = fragment.find('.child-node')[0]
          keymap.handleKeyEvent(keydownEvent('x', target: target))

          expect(fooHandler).toHaveBeenCalled()

  describe ".bindKey(selector, pattern, eventName)", ->
    it "binds a single key", ->
      keymap.bindKey '.child-node', 'z', 'foo'

      fooHandler = jasmine.createSpy('fooHandler')
      fragment.on 'foo', fooHandler

      target = fragment.find('.child-node')[0]
      keymap.handleKeyEvent(keydownEvent('z', target: target))

      expect(fooHandler).toHaveBeenCalled()

  describe ".keystrokeStringForEvent(event)", ->
    describe "when no modifiers are pressed", ->
      it "returns a string that identifies the key pressed", ->
        expect(keymap.keystrokeStringForEvent(keydownEvent('a'))).toBe 'a'
        expect(keymap.keystrokeStringForEvent(keydownEvent('['))).toBe '['
        expect(keymap.keystrokeStringForEvent(keydownEvent('*'))).toBe '*'
        expect(keymap.keystrokeStringForEvent(keydownEvent('left'))).toBe 'left'
        expect(keymap.keystrokeStringForEvent(keydownEvent('\b'))).toBe 'backspace'

    describe "when ctrl, alt or meta is pressed with a non-modifier key", ->
      it "returns a string that identifies the key pressed", ->
        expect(keymap.keystrokeStringForEvent(keydownEvent('a', altKey: true))).toBe 'alt-a'
        expect(keymap.keystrokeStringForEvent(keydownEvent('[', metaKey: true))).toBe 'meta-['
        expect(keymap.keystrokeStringForEvent(keydownEvent('*', ctrlKey: true))).toBe 'ctrl-*'
        expect(keymap.keystrokeStringForEvent(keydownEvent('left', ctrlKey: true, metaKey: true, altKey: true))).toBe 'alt-ctrl-meta-left'

    describe "when shift is pressed when a non-modifer key", ->
      it "returns a string that identifies the key pressed", ->
        expect(keymap.keystrokeStringForEvent(keydownEvent('A', shiftKey: true))).toBe 'A'
        expect(keymap.keystrokeStringForEvent(keydownEvent('{', shiftKey: true))).toBe '{'
        expect(keymap.keystrokeStringForEvent(keydownEvent('left', shiftKey: true))).toBe 'shift-left'
        expect(keymap.keystrokeStringForEvent(keydownEvent('Left', shiftKey: true))).toBe 'shift-left'
