DecorationManager = require '../src/decoration-manager'
_ = require 'underscore-plus'

describe "DecorationManager", ->
  [decorationManager, buffer, defaultMarkerLayer] = []

  beforeEach ->
    buffer = atom.project.bufferForPathSync('sample.js')
    displayLayer = buffer.addDisplayLayer()
    defaultMarkerLayer = displayLayer.addMarkerLayer()
    decorationManager = new DecorationManager(displayLayer, defaultMarkerLayer)

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

  afterEach ->
    decorationManager.destroy()
    buffer.release()

  describe "decorations", ->
    [marker, decoration, decorationProperties] = []
    beforeEach ->
      marker = defaultMarkerLayer.markBufferRange([[2, 13], [3, 15]])
      decorationProperties = {type: 'line-number', class: 'one'}
      decoration = decorationManager.decorateMarker(marker, decorationProperties)

    it "can add decorations associated with markers and remove them", ->
      expect(decoration).toBeDefined()
      expect(decoration.getProperties()).toBe decorationProperties
      expect(decorationManager.decorationForId(decoration.id)).toBe decoration
      expect(decorationManager.decorationsForScreenRowRange(2, 3)[marker.id][0]).toBe decoration

      decoration.destroy()
      expect(decorationManager.decorationsForScreenRowRange(2, 3)[marker.id]).not.toBeDefined()
      expect(decorationManager.decorationForId(decoration.id)).not.toBeDefined()

    it "will not fail if the decoration is removed twice", ->
      decoration.destroy()
      decoration.destroy()
      expect(decorationManager.decorationForId(decoration.id)).not.toBeDefined()

    it "does not allow destroyed markers to be decorated", ->
      marker.destroy()
      expect(->
        decorationManager.decorateMarker(marker, {type: 'overlay', item: document.createElement('div')})
      ).toThrow("Cannot decorate a destroyed marker")
      expect(decorationManager.getOverlayDecorations()).toEqual []

    describe "when a decoration is updated via Decoration::update()", ->
      it "emits an 'updated' event containing the new and old params", ->
        decoration.onDidChangeProperties updatedSpy = jasmine.createSpy()
        decoration.setProperties type: 'line-number', class: 'two'

        {oldProperties, newProperties} = updatedSpy.mostRecentCall.args[0]
        expect(oldProperties).toEqual decorationProperties
        expect(newProperties).toEqual {type: 'line-number', gutterName: 'line-number', class: 'two'}

    describe "::getDecorations(properties)", ->
      it "returns decorations matching the given optional properties", ->
        expect(decorationManager.getDecorations()).toEqual [decoration]
        expect(decorationManager.getDecorations(class: 'two').length).toEqual 0
        expect(decorationManager.getDecorations(class: 'one').length).toEqual 1

  describe "::decorateMarker", ->
    describe "when decorating gutters", ->
      [marker] = []

      beforeEach ->
        marker = defaultMarkerLayer.markBufferRange([[1, 0], [1, 0]])

      it "creates a decoration that is both of 'line-number' and 'gutter' type when called with the 'line-number' type", ->
        decorationProperties = {type: 'line-number', class: 'one'}
        decoration = decorationManager.decorateMarker(marker, decorationProperties)
        expect(decoration.isType('line-number')).toBe true
        expect(decoration.isType('gutter')).toBe true
        expect(decoration.getProperties().gutterName).toBe 'line-number'
        expect(decoration.getProperties().class).toBe 'one'

      it "creates a decoration that is only of 'gutter' type if called with the 'gutter' type and a 'gutterName'", ->
        decorationProperties = {type: 'gutter', gutterName: 'test-gutter', class: 'one'}
        decoration = decorationManager.decorateMarker(marker, decorationProperties)
        expect(decoration.isType('gutter')).toBe true
        expect(decoration.isType('line-number')).toBe false
        expect(decoration.getProperties().gutterName).toBe 'test-gutter'
        expect(decoration.getProperties().class).toBe 'one'
