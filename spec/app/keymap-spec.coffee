Keymap = require 'keymap'
$ = require 'jquery'

describe "Keymap", ->
  fragment = null
  keymap = null

  beforeEach ->
    keymap = new Keymap
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

    it "adds a 'keystrokes' string to the event object", ->
      event = keydownEvent('x', altKey: true, metaKey: true)
      keymap.handleKeyEvent(event)
      expect(event.keystrokes).toBe 'alt-meta-x'

    describe "when no binding matches the event's keystroke", ->
      it "returns true, so the event continues to propagate", ->
        expect(keymap.handleKeyEvent(keydownEvent('0', target: fragment[0]))).toBeTruthy()

    describe "when at least one binding fully matches the event's keystroke", ->
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
          expect(event.keystrokes).toBe 'x'

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

    describe "when at least one binding partially matches the event's keystroke", ->
      [quitHandler, closeOtherWindowsHandler] = []

      beforeEach ->
        keymap.bindKeys "*",
          'ctrl-x ctrl-c': 'quit'
          'ctrl-x 1': 'close-other-windows'

        quitHandler = jasmine.createSpy('quitHandler')
        closeOtherWindowsHandler = jasmine.createSpy('closeOtherWindowsHandler')
        fragment.on 'quit', quitHandler
        fragment.on 'close-other-windows', closeOtherWindowsHandler

      it "only matches entire keystroke patters", ->
        expect(keymap.handleKeyEvent(keydownEvent('c', target: fragment[0]))).toBeTruthy()

      describe "when the event's target node matches a selector with a partially matching multi-stroke binding", ->
        describe "when a second keystroke added to the first to match a multi-stroke binding completely", ->
          it "triggers the event associated with the matched multi-stroke binding", ->
            expect(keymap.handleKeyEvent(keydownEvent('x', target: fragment[0], ctrlKey: true))).toBeFalsy()
            expect(keymap.handleKeyEvent(keydownEvent('c', target: fragment[0], ctrlKey: true))).toBeFalsy()

            expect(quitHandler).toHaveBeenCalled()
            expect(closeOtherWindowsHandler).not.toHaveBeenCalled()
            quitHandler.reset()

            expect(keymap.handleKeyEvent(keydownEvent('x', target: fragment[0], ctrlKey: true))).toBeFalsy()
            expect(keymap.handleKeyEvent(keydownEvent('1', target: fragment[0]))).toBeFalsy()

            expect(quitHandler).not.toHaveBeenCalled()
            expect(closeOtherWindowsHandler).toHaveBeenCalled()

        describe "when a second keystroke added to the first doesn't match any bindings", ->
          it "clears the queued keystrokes without triggering any events", ->
            expect(keymap.handleKeyEvent(keydownEvent('x', target: fragment[0], ctrlKey: true))).toBeFalsy()
            expect(keymap.handleKeyEvent(keydownEvent('c', target: fragment[0]))).toBeFalsy()
            expect(quitHandler).not.toHaveBeenCalled()
            expect(closeOtherWindowsHandler).not.toHaveBeenCalled()

            expect(keymap.handleKeyEvent(keydownEvent('c', target: fragment[0]))).toBeTruthy()

      describe "when the event's target node descends from multiple nodes that match selectors with a partial binding match", ->
        it "allows any of the bindings to be triggered upon a second keystroke, favoring the most specific selector", ->
           keymap.bindKeys ".grandchild-node", 'ctrl-x ctrl-c': 'more-specific-quit'
           grandchildNode = fragment.find('.grandchild-node')[0]
           moreSpecificQuitHandler = jasmine.createSpy('moreSpecificQuitHandler')
           fragment.on 'more-specific-quit', moreSpecificQuitHandler

           expect(keymap.handleKeyEvent(keydownEvent('x', target: grandchildNode, ctrlKey: true))).toBeFalsy()
           expect(keymap.handleKeyEvent(keydownEvent('1', target: grandchildNode))).toBeFalsy()
           expect(quitHandler).not.toHaveBeenCalled()
           expect(moreSpecificQuitHandler).not.toHaveBeenCalled()
           expect(closeOtherWindowsHandler).toHaveBeenCalled()
           closeOtherWindowsHandler.reset()

           expect(keymap.handleKeyEvent(keydownEvent('x', target: grandchildNode, ctrlKey: true))).toBeFalsy()
           expect(keymap.handleKeyEvent(keydownEvent('c', target: grandchildNode, ctrlKey: true))).toBeFalsy()
           expect(quitHandler).not.toHaveBeenCalled()
           expect(closeOtherWindowsHandler).not.toHaveBeenCalled()
           expect(moreSpecificQuitHandler).toHaveBeenCalled()

      describe "when there is a complete binding with a less specific selector", ->
        it "favors the more specific partial match", ->

      describe "when there is a complete binding with a more specific selector", ->
        it "favors the more specific complete match", ->

  describe ".bindKeys(selector, fnOrMap)", ->
    describe "when called with a selector and a hash", ->
      it "normalizes the key patterns in the hash to put the modifiers in alphabetical order", ->
        fooHandler = jasmine.createSpy('fooHandler')
        fragment.on 'foo', fooHandler
        keymap.bindKeys '*', 'ctrl-alt-delete': 'foo'
        result = keymap.handleKeyEvent(keydownEvent('delete', ctrlKey: true, altKey: true, target: fragment[0]))
        expect(result).toBe(false)
        expect(fooHandler).toHaveBeenCalled()

        fooHandler.reset()
        keymap.bindKeys '*', 'ctrl-alt--': 'foo'
        result = keymap.handleKeyEvent(keydownEvent('-', ctrlKey: true, altKey: true, target: fragment[0]))
        expect(result).toBe(false)
        expect(fooHandler).toHaveBeenCalled()

    describe "when called with a selector and a function", ->
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

  describe ".bindingsForElement(element)", ->
    it "returns the matching bindings for the element", ->
      keymap.bindKeys '.command-mode', 'c': 'c'
      keymap.bindKeys '.grandchild-node', 'g': 'g'

      bindings = keymap.bindingsForElement(fragment.find('.grandchild-node'))
      expect(Object.keys(bindings).length).toBe 2
      expect(bindings['c']).toEqual "c"
      expect(bindings['g']).toEqual "g"

    describe "when multiple bindings match a keystroke", ->
      it "only returns bindings that match the most specific selector", ->
        keymap.bindKeys '.command-mode', 'g': 'command-mode'
        keymap.bindKeys '.command-mode .grandchild-node', 'g': 'command-and-grandchild-node'
        keymap.bindKeys '.grandchild-node', 'g': 'grandchild-node'

        bindings = keymap.bindingsForElement(fragment.find('.grandchild-node'))
        expect(Object.keys(bindings).length).toBe 1
        expect(bindings['g']).toEqual "command-and-grandchild-node"
