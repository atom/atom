{View, $, $$} = require '../src/space-pen-extensions'

describe "SpacePen extensions", ->
  class TestView extends View
    @content: -> @div()

  [view, parent] = []

  beforeEach ->
    view = new TestView
    parent = $$ -> @div()
    parent.append(view)

  describe "View.subscribe(eventEmitter, eventName, callback)", ->
    [emitter, eventHandler] = []

    beforeEach ->
      eventHandler = jasmine.createSpy 'eventHandler'
      emitter = $$ -> @div()
      view.subscribe emitter, 'foo', eventHandler

    it "subscribes to the given event emitter and unsubscribes when unsubscribe is called", ->
      emitter.trigger "foo"
      expect(eventHandler).toHaveBeenCalled()

  describe "tooltips", ->
    describe "when the window is resized", ->
      it "hides the tooltips", ->
        class TooltipView extends View
          @content: ->
            @div()

        view = new TooltipView()
        view.attachToDom()
        view.setTooltip('this is a tip')

        view.tooltip('show')
        expect($(document.body).find('.tooltip')).toBeVisible()

        $(window).trigger('resize')
        expect($(document.body).find('.tooltip')).not.toExist()
