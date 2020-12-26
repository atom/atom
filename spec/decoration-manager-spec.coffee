DecorationManager = require '../src/decoration-manager'
TextEditor = require '../src/text-editor'

describe "DecorationManager", ->
  [decorationManager, buffer, editor, markerLayer1, markerLayer2] = []

  beforeEach ->
    buffer = atom.project.bufferForPathSync('sample.js')
    editor = new TextEditor({buffer})
    markerLayer1 = editor.addMarkerLayer()
    markerLayer2 = editor.addMarkerLayer()
    decorationManager = new DecorationManager(editor)

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
      layer = editor.addMarkerLayer()
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

  describe "text decorations", ->
    beforeEach ->
      # Initially, there is only the syntax text decoration layer provided by
      # TokenizedBuffer. We remove it from display layer, along with any other
      # editor decorations, to maximize clarity in the assertions of this
      # section.
      editor.setText("""
        Lorem ipsum dolor sit amet
        consectetur adipisicing elit
        sed do eiusmod tempor incididunt
        ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud
        exercitation ullamco laboris nisi
        ut aliquip ex ea commodo consequat.
      """)
      editor.displayLayer.removeTextDecorationLayer(editor.displayLayer.getTextDecorationLayers()[0])
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

    it "adds a text decoration layer based on the decorated markers or marker layer", ->
      layer1Marker1 = markerLayer1.markBufferRange([[0, 2], [0, 5]])
      layer1Marker2 = markerLayer1.markBufferRange([[1, 1], [1, 4]])
      layer1Marker3 = markerLayer1.markBufferRange([[2, 0], [2, 3]])

      decorationManager.decorateMarker(layer1Marker1, {type: 'text', class: 'marker1-class1'})
      decorationManager.decorateMarker(layer1Marker1, {type: 'text', class: 'marker1-class2'})
      decorationManager.decorateMarker(layer1Marker2, {type: 'text', style: {fontFamily: 'marker2-family'}})
      decorationManager.decorateMarker(layer1Marker1, {type: 'overlay', class: 'unused', style: {color: 'unused'}}) # Don't use styles and class names from other decoration types.
      expect(mapScreenRowToHTML(editor, 0)).toBe('Lo<span class="marker1-class1 marker1-class2">rem</span> ipsum dolor sit amet')
      expect(mapScreenRowToHTML(editor, 1)).toBe('c<span style={"fontFamily":"marker2-family"}>ons</span>ectetur adipisicing elit')
      expect(mapScreenRowToHTML(editor, 2)).toBe('<span>sed</span> do eiusmod tempor incididunt')

      decorationManager.decorateMarker(layer1Marker2, {type: 'text', style: {fontSize: 'marker2-size'}})
      decorationManager.decorateMarker(layer1Marker3, {type: 'text', class: 'marker3-class'})
      decorationManager.decorateMarker(layer1Marker3, {type: 'text', style: {color: 'marker3-color'}})
      expect(mapScreenRowToHTML(editor, 0)).toBe('Lo<span class="marker1-class1 marker1-class2">rem</span> ipsum dolor sit amet')
      expect(mapScreenRowToHTML(editor, 1)).toBe('c<span style={"fontFamily":"marker2-family","fontSize":"marker2-size"}>ons</span>ectetur adipisicing elit')
      expect(mapScreenRowToHTML(editor, 2)).toBe('<span style={"color":"marker3-color"} class="marker3-class">sed</span> do eiusmod tempor incididunt')

      layer1Decoration = decorationManager.decorateMarkerLayer(markerLayer1, {type: 'text', class: 'layer-class', style: {color: 'layer-color'}})
      decorationManager.decorateMarkerLayer(markerLayer1, {type: 'highlight', class: 'layer-class', style: {color: 'layer-color'}}) # Don't use styles and class names from other decoration types.
      expect(mapScreenRowToHTML(editor, 0)).toBe('Lo<span style={"color":"layer-color"} class="marker1-class1 marker1-class2 layer-class">rem</span> ipsum dolor sit amet')
      expect(mapScreenRowToHTML(editor, 1)).toBe('c<span style={"color":"layer-color","fontFamily":"marker2-family","fontSize":"marker2-size"} class="layer-class">ons</span>ectetur adipisicing elit')
      expect(mapScreenRowToHTML(editor, 2)).toBe('<span style={"color":"marker3-color"} class="marker3-class layer-class">sed</span> do eiusmod tempor incididunt')

      layer2Decoration = decorationManager.decorateMarkerLayer(markerLayer2, {type: 'text', class: 'layer2-class'})
      markerLayer2.markBufferRange([[0, 0], [0, 1]])
      expect(mapScreenRowToHTML(editor, 0)).toBe('<span class="layer2-class">L</span>o<span style={"color":"layer-color"} class="marker1-class1 marker1-class2 layer-class">rem</span> ipsum dolor sit amet')
      expect(mapScreenRowToHTML(editor, 1)).toBe('c<span style={"color":"layer-color","fontFamily":"marker2-family","fontSize":"marker2-size"} class="layer-class">ons</span>ectetur adipisicing elit')
      expect(mapScreenRowToHTML(editor, 2)).toBe('<span style={"color":"marker3-color"} class="marker3-class layer-class">sed</span> do eiusmod tempor incididunt')

    it "adds only one text decoration layer per marker layer, destroying it when the last decoration is destroyed", ->
      # Add other marker decorations to ensure text decoration layers are
      # removed when the last decoration with {type: 'text'} is gone.
      decorationManager.decorateMarkerLayer(markerLayer1, {type: 'overlay'})
      decorationManager.decorateMarker(markerLayer1.markBufferPosition([0, 0]), {type: 'cursor'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

      # Destroy the only marker decoration.
      marker1 = markerLayer1.markBufferRange([[0, 2], [0, 5]])
      marker1Decoration1 = decorationManager.decorateMarker(marker1, {type: 'text'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      marker1Decoration1.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

      # Destroy the only marker.
      marker1Decoration2 = decorationManager.decorateMarker(marker1, {type: 'text'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      marker1.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

      # Destroy the only layer decoration.
      marker2 = markerLayer1.markBufferRange([[0, 0], [0, 4]])
      layerDecoration1 = decorationManager.decorateMarkerLayer(markerLayer1, {type: 'text'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      layerDecoration1.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

      # Destroy the marker decoration, then the layer decoration.
      layerDecoration2 = decorationManager.decorateMarkerLayer(markerLayer1, {type: 'text'})
      marker2Decoration1 = decorationManager.decorateMarker(marker2, {type: 'text'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      marker2Decoration1.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      layerDecoration2.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

      # Destroy the layer decoration, then the marker decoration.
      layerDecoration3 = decorationManager.decorateMarkerLayer(markerLayer1, {type: 'text'})
      marker2Decoration2 = decorationManager.decorateMarker(marker2, {type: 'text'})
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      layerDecoration3.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(1)
      marker2Decoration2.destroy()
      expect(editor.displayLayer.getTextDecorationLayers().length).toBe(0)

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

mapScreenRowToHTML = (editor, screenRow) ->
  {displayLayer} = editor
  {lineText, tags} = editor.screenLineForScreenRow(screenRow)
  text = ''
  startIndex = 0
  for tag in tags
    if displayLayer.isOpenTag(tag)
      style = displayLayer.inlineStyleForTag(tag)
      className = displayLayer.classNameForTag(tag)
      text += '<span'
      text += " style=#{JSON.stringify(style)}" if style
      text += " class=\"#{className}\"" if className
      text += '>'
    else if displayLayer.isCloseTag(tag)
      text += '</span>'
    else
      text += lineText.substr(startIndex, tag)
      startIndex += tag
  text
