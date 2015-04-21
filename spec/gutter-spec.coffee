Gutter = require '../src/gutter'

describe 'Gutter', ->
  fakeGutterContainer = {}
  name = 'name'

  describe '::hide', ->
    it 'hides the gutter if it is visible.', ->
      options =
        name: name
        visible: true
      gutter = new Gutter fakeGutterContainer, options
      events = []
      gutter.onDidChangeVisible (gutter) ->
        events.push gutter.isVisible()

      expect(gutter.isVisible()).toBe true
      gutter.hide()
      expect(gutter.isVisible()).toBe false
      expect(events).toEqual [false]
      gutter.hide()
      expect(gutter.isVisible()).toBe false
      # An event should only be emitted when the visibility changes.
      expect(events.length).toBe 1

  describe '::show', ->
    it 'shows the gutter if it is hidden.', ->
      options =
        name: name
        visible: false
      gutter = new Gutter fakeGutterContainer, options
      events = []
      gutter.onDidChangeVisible (gutter) ->
        events.push gutter.isVisible()

      expect(gutter.isVisible()).toBe false
      gutter.show()
      expect(gutter.isVisible()).toBe true
      expect(events).toEqual [true]
      gutter.show()
      expect(gutter.isVisible()).toBe true
      # An event should only be emitted when the visibility changes.
      expect(events.length).toBe 1

  describe '::destroy', ->
    [mockGutterContainer, mockGutterContainerRemovedGutters] = []

    beforeEach ->
      mockGutterContainerRemovedGutters = []
      mockGutterContainer = removeGutter: (destroyedGutter) ->
        mockGutterContainerRemovedGutters.push destroyedGutter

    it 'removes the gutter from its container.', ->
      gutter = new Gutter mockGutterContainer, {name}
      gutter.destroy()
      expect(mockGutterContainerRemovedGutters).toEqual([gutter])

    it 'calls all callbacks registered on ::onDidDestroy.', ->
      gutter = new Gutter mockGutterContainer, {name}
      didDestroy = false
      gutter.onDidDestroy ->
        didDestroy = true
      gutter.destroy()
      expect(didDestroy).toBe true

    it 'does not allow destroying the line-number gutter', ->
      gutter = new Gutter mockGutterContainer, {name: 'line-number'}
      expect(gutter.destroy).toThrow()
