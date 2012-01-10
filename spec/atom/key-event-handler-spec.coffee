KeyEventHandler = require 'key-event-handler'
$ = require 'jquery'

describe "KeyEventHandler", ->
  handler = null

  beforeEach ->
    handler = new KeyEventHandler

  fdescribe "handleKeypress", ->
    describe "when there is a mapping in a selector that matches the event's element", ->
      fragment = null
      deleteCharHandler = null
      insertCharHandler = null

      beforeEach ->
        handler.bindKeys '.command-mode', 'x': 'deleteChar'
        handler.bindKeys '.insert-mode', 'x': 'insertChar'

        fragment = $('<div class="command-mode">')
        deleteCharHandler = jasmine.createSpy 'deleteCharHandler'
        insertCharHandler = jasmine.createSpy 'insertCharHandler'
        fragment.on 'deleteChar', deleteCharHandler
        fragment.on 'insertChar', insertCharHandler

      it "only triggers an event based on the key-binding in that selector", ->
        handler.handleKeypress(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).toHaveBeenCalled()
        expect(insertCharHandler).not.toHaveBeenCalled()

        deleteCharHandler.reset()
        fragment.removeClass('command-mode').addClass('insert-mode')

        handler.handleKeypress(keypressEvent('x', target: fragment[0]))
        expect(deleteCharHandler).not.toHaveBeenCalled()
        expect(insertCharHandler).toHaveBeenCalled()

