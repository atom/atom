{$} = require '../src/space-pen-extensions'

describe "SpacePen extensions", ->
  describe "tooltips", ->
    describe "when the window is resized", ->
      it "hides the tooltips", ->
        view = $('<div></div>')
        view.attachToDom()
        view.setTooltip('this is a tip')

        view.tooltip('show')
        expect($(document.body).find('.tooltip')).toBeVisible()

        $(window).trigger('resize')
        expect($(document.body).find('.tooltip')).not.toExist()
