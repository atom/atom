KeyEventHandler = require 'key-event-handler'
$ = require 'jquery'

describe "KeyEventHandler", ->
  handler = null

  beforeEach ->
    handler = new KeyEventHandler

  describe "handleKeypress", ->
    fragment = null
    deleteCharHandler = null
    insertCharHandler = null

    beforeEach ->
      handler.bindKeys '.command-mode', 'x': 'deleteChar'
      handler.bindKeys '.insert-mode', 'x': 'insertChar'

      fragment = $ """
        <div class="command-mode">
          <div class="descendant-node"/>
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
        target = fragment.find('.descendant-node')[0]
        handler.handleKeypress(keypressEvent('x', target: target))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeypress(keypressEvent('x', target: target))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

