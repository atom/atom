GlobalKeymap = require 'global-keymap'
$ = require 'jquery'

describe "GlobalKeymap", ->
  handler = null

  beforeEach ->
    handler = new GlobalKeymap

  describe "handleKeyEvent", ->
    fragment = null
    deleteCharHandler = null
    insertCharHandler = null

    beforeEach ->
      handler.bindKeys '.command-mode', 'x': 'deleteChar'
      handler.bindKeys '.insert-mode', 'x': 'insertChar'

      fragment = $ """
        <div class="command-mode">
          <div class="child-node">
            <div class="grandchild-node"/>
          </div>
        </div>
      """

      deleteCharHandler = jasmine.createSpy 'deleteCharHandler'
      insertCharHandler = jasmine.createSpy 'insertCharHandler'
      fragment.on 'deleteChar', deleteCharHandler
      fragment.on 'insertChar', insertCharHandler

    describe "when the event's target node matches a selector with a matching binding", ->
      it "triggers the command event associated with that binding on the target node", ->
        handler.handleKeyEvent(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeyEvent(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

    describe "when the event's target node *descends* from a selector with a matching binding", ->
      it "triggers the command event associated with that binding on the target node", ->
        target = fragment.find('.child-node')[0]
        handler.handleKeyEvent(keypressEvent('x', target: target))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeyEvent(keypressEvent('x', target: target))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

    describe "when the event's target node descends from *multiple* selectors with a matching binding", ->
      it "only triggers bindings on selectors associated with the closest ancestor node", ->
        handler.bindKeys '.child-node', 'x': 'foo'
        fooHandler = jasmine.createSpy 'fooHandler'
        fragment.on 'foo', fooHandler

        target = fragment.find('.grandchild-node')[0]
        handler.handleKeyEvent(keypressEvent('x', target: target))
        expect(fooHandler).toHaveBeenCalled()
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

    describe "when the event bubbles to a node that matches multiple selectors", ->
      it "triggers the binding for the most specific selector", ->
        handler.bindKeys 'div .child-node', 'x': 'foo'
        handler.bindKeys '.command-mode .child-node', 'x': 'baz'
        handler.bindKeys '.child-node', 'x': 'bar'

        fooHandler = jasmine.createSpy 'fooHandler'
        barHandler = jasmine.createSpy 'barHandler'
        bazHandler = jasmine.createSpy 'bazHandler'
        fragment.on 'foo', fooHandler
        fragment.on 'bar', barHandler
        fragment.on 'baz', bazHandler

        target = fragment.find('.grandchild-node')[0]
        handler.handleKeyEvent(keypressEvent('x', target: target))

        expect(fooHandler).not.toHaveBeenCalled()
        expect(barHandler).not.toHaveBeenCalled()
        expect(bazHandler).toHaveBeenCalled()
