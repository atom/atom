KeyEventHandler = require 'key-event-handler'
$ = require 'jquery'

describe "KeyEventHandler", ->
  handler = null

  beforeEach ->
    handler = new KeyEventHandler

  fdescribe "handleKeypress", ->
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
        handler.handleKeypress(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeypress(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

    describe "when the event's target node *descends* from a selector with a matching binding", ->
      it "triggers the command event associated with that binding on the target node", ->
        target = fragment.find('.child-node')[0]
        handler.handleKeypress(keypressEvent('x', target: target))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeypress(keypressEvent('x', target: target))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

    describe "when the event's target node descends from *multiple* selectors with a matching binding", ->
      it "only triggers bindings on selectors associated with the closest ancestor node", ->
        handler.bindKeys '.child-node', 'x': 'foo'
        fooHandler = jasmine.createSpy 'fooHandler'
        fragment.on 'foo', fooHandler

        target = fragment.find('.grandchild-node')[0]
        handler.handleKeypress(keypressEvent('x', target: target))
        expect(fooHandler).toHaveBeenCalled()
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

