Panel = require '../src/panel'

describe "Panel", ->
  [panel] = []

  class TestPanelItem
    constructior: ->

  beforeEach ->
    panel = new Panel(item: new TestPanelItem())

  describe "changing panel visibility", ->
    it 'emits an event when visibility changes', ->
      panel.onDidChangeVisible spy = jasmine.createSpy()

      panel.hide()
      expect(panel.isVisible()).toBe false
      expect(spy).toHaveBeenCalledWith(false)
      spy.reset()

      panel.show()
      expect(panel.isVisible()).toBe true
      expect(spy).toHaveBeenCalledWith(true)

      panel.destroy()
      expect(panel.isVisible()).toBe false
      expect(spy).toHaveBeenCalledWith(false)
