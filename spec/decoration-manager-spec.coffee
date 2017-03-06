DecorationManager = require '../src/decoration-manager'

describe "DecorationManager", ->
  [decorationManager, buffer, displayLayer, markerLayer1, markerLayer2] = []

  beforeEach ->
    buffer = atom.project.bufferForPathSync('sample.js')
    displayLayer = buffer.addDisplayLayer()
    markerLayer1 = displayLayer.addMarkerLayer()
    markerLayer2 = displayLayer.addMarkerLayer()
    decorationManager = new DecorationManager(displayLayer)

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

  afterEach ->
    buffer.destroy()

  describe "decorations", ->
    [layer1Marker, layer2Marker, layer1MarkerDecoration, layer2MarkerDecoration, decorationProperties] = []
    beforeEach ->
      layer1Marker = markerLayer1.markBufferRange([[2, 13], [3, 15]])
      decorationProperties = {type: 'line-number', class: 'one'}
      layer1MarkerDecoration = decorationManager.decorateMarker(layer1Marker, decorationProperties)
      layer2Marker = markerLayer2.markBufferRange([[2, 13], [3, 15]])
      layer2MarkerDecoration = decorationManager.decorateMarker(layer2Marker, decorationProperties)

    it "can add decorations associated with markers and remove them", ->
      expect(layer1MarkerDecoration).toBeDefined()
      expect(layer1MarkerDecoration.getProperties()).toBe decorationProperties
      expect(decorationManager.decorationsForScreenRowRange(2, 3)).toEqual {
        "#{layer1Marker.id}": [layer1MarkerDecoration],
        "#{layer2Marker.id}": [layer2MarkerDecoration]
      }

      layer1MarkerDecoration.destroy()
      expect(decorationManager.decorationsForScreenRowRange(2, 3)[layer1Marker.id]).not.toBeDefined()
      layer2MarkerDecoration.destroy()
      expect(decorationManager.decorationsForScreenRowRange(2, 3)[layer2Marker.id]).not.toBeDefined()

    it "will not fail if the decoration is removed twice", ->
      layer1MarkerDecoration.destroy()
      layer1MarkerDecoration.destroy()

    it "does not allow destroyed markers to be decorated", ->
      layer1Marker.destroy()
      expect(->
        decorationManager.decorateMarker(layer1Marker, {type: 'overlay', item: document.createElement('div')})
      ).toThrow("Cannot decorate a destroyed marker")
      expect(decorationManager.getOverlayDecorations()).toEqual []

    it "does not allow destroyed marker layers to be decorated", ->
      layer = displayLayer.addMarkerLayer()
      layer.destroy()
      expect(->
        decorationManager.decorateMarkerLayer(layer, {type: 'highlight'})
      ).toThrow("Cannot decorate a destroyed marker layer")

    describe "when a decoration is updated via Decoration::update()", ->
      it "emits an 'updated' event containing the new and old params", ->
        layer1MarkerDecoration.onDidChangeProperties updatedSpy = jasmine.createSpy()
        layer1MarkerDecoration.setProperties type: 'line-number', class: 'two'

        {oldProperties, newProperties} = updatedSpy.mostRecentCall.args[0]
        expect(oldProperties).toEqual decorationProperties
        expect(newProperties).toEqual {type: 'line-number', gutterName: 'line-number', class: 'two'}

    describe "::getDecorations(properties)", ->
      it "returns decorations matching the given optional properties", ->
        expect(decorationManager.getDecorations()).toEqual [layer1MarkerDecoration, layer2MarkerDecoration]
        expect(decorationManager.getDecorations(class: 'two').length).toEqual 0
        expect(decorationManager.getDecorations(class: 'one').length).toEqual 2

  describe "::decorateMarker", ->
    describe "when decorating gutters", ->
      [layer1Marker] = []

      beforeEach ->
        layer1Marker = markerLayer1.markBufferRange([[1, 0], [1, 0]])

      it "creates a decoration that is both of 'line-number' and 'gutter' type when called with the 'line-number' type", ->
        decorationProperties = {type: 'line-number', class: 'one'}
        layer1MarkerDecoration = decorationManager.decorateMarker(layer1Marker, decorationProperties)
        expect(layer1MarkerDecoration.isType('line-number')).toBe true
        expect(layer1MarkerDecoration.isType('gutter')).toBe true
        expect(layer1MarkerDecoration.getProperties().gutterName).toBe 'line-number'
        expect(layer1MarkerDecoration.getProperties().class).toBe 'one'

      it "creates a decoration that is only of 'gutter' type if called with the 'gutter' type and a 'gutterName'", ->
        decorationProperties = {type: 'gutter', gutterName: 'test-gutter', class: 'one'}
        layer1MarkerDecoration = decorationManager.decorateMarker(layer1Marker, decorationProperties)
        expect(layer1MarkerDecoration.isType('gutter')).toBe true
        expect(layer1MarkerDecoration.isType('line-number')).toBe false
        expect(layer1MarkerDecoration.getProperties().gutterName).toBe 'test-gutter'
        expect(layer1MarkerDecoration.getProperties().class).toBe 'one'
