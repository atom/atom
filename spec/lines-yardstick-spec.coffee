LinesYardstick = require "../src/lines-yardstick"

describe "LinesYardstick", ->
  [editor, mockPresenter, mockLineNodesProvider, createdLineNodes, linesYardstick] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      createdLineNodes = []
      availableScreenRows = {}
      screenRowsToMeasure = []

      buildLineNode = (screenRow) ->
        tokenizedLine = editor.tokenizedLineForScreenRow(screenRow)
        iterator = tokenizedLine.getTokenIterator()
        lineNode = document.createElement("div")
        lineNode.style.whiteSpace = "pre"
        while iterator.next()
          span = document.createElement("span")
          span.className = iterator.getScopes().join(' ').replace(/\.+/g, ' ')
          span.textContent = iterator.getText()
          lineNode.appendChild(span)

        jasmine.attachToDOM(lineNode)
        createdLineNodes.push(lineNode)
        lineNode

      mockPresenter =
        isBatching: -> true
        setScreenRowsToMeasure: (screenRows) -> screenRowsToMeasure = screenRows
        clearScreenRowsToMeasure: -> setScreenRowsToMeasure = []
        getPreMeasurementState: ->
          state = {}
          for screenRow in screenRowsToMeasure
            tokenizedLine = editor.tokenizedLineForScreenRow(screenRow)
            state[tokenizedLine.id] = screenRow
          state

      mockLineNodesProvider =
        updateSync: (state) -> availableScreenRows = state
        lineNodeForLineIdAndScreenRow: (lineId, screenRow) ->
          if availableScreenRows[lineId] isnt screenRow
            throw new Error("No line node found!")

          buildLineNode(screenRow)

      editor.setLineHeightInPixels(14)
      linesYardstick = new LinesYardstick(editor, mockPresenter, mockLineNodesProvider)

  afterEach ->
    lineNode.remove() for lineNode in createdLineNodes
    atom.themes.removeStylesheet('test')

  describe "::pixelPositionForScreenPosition(screenPosition)", ->
    it "converts screen positions to pixel positions", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 12px;
        font-family: monospace;
      }
      .function {
        font-size: 16px
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([0, 0])).toEqual({left: 0, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([0, 1])).toEqual({left: 7, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([0, 5])).toEqual({left: 38, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([1, 6])).toEqual({left: 42, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([1, 9])).toEqual({left: 72, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, Infinity])).toEqual({left: 280, top: 28})

    it "reuses already computed pixel positions unless it is invalidated", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 16px;
        font-family: monospace;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 20, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 60, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 100, top: 70})

      atom.styles.addStyleSheet """
      * {
        font-size: 20px;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 20, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 60, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 100, top: 70})

      linesYardstick.invalidateCache()

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 24, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 72, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 120, top: 70})

    describe "::screenPositionForPixelPosition(pixelPosition)", ->
      it "converts pixel positions to screen positions", ->
        atom.styles.addStyleSheet """
        * {
          font-size: 12px;
          font-family: monospace;
        }
        .function {
          font-size: 16px
        }
        """

        expect(linesYardstick.screenPositionForPixelPosition({top: 0, left: 12.5})).toEqual([0, 2])
        expect(linesYardstick.screenPositionForPixelPosition({top: 14, left: 17.8})).toEqual([1, 3])
        expect(linesYardstick.screenPositionForPixelPosition({top: 28, left: 100})).toEqual([2, 14])
        expect(linesYardstick.screenPositionForPixelPosition({top: 32, left: 24.3})).toEqual([2, 3])
        expect(linesYardstick.screenPositionForPixelPosition({top: 46, left: 66.5})).toEqual([3, 9])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 99.9})).toEqual([5, 14])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 221.5})).toEqual([5, 29])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 222})).toEqual([5, 30])

      it "clips pixel positions above buffer start", ->
        expect(linesYardstick.screenPositionForPixelPosition(top: -Infinity, left: -Infinity)).toEqual [0, 0]
        expect(linesYardstick.screenPositionForPixelPosition(top: -Infinity, left: Infinity)).toEqual [0, 0]
        expect(linesYardstick.screenPositionForPixelPosition(top: -1, left: Infinity)).toEqual [0, 0]
        expect(linesYardstick.screenPositionForPixelPosition(top: 0, left: Infinity)).toEqual [0, 29]

      it "clips pixel positions below buffer end", ->
        expect(linesYardstick.screenPositionForPixelPosition(top: Infinity, left: -Infinity)).toEqual [12, 2]
        expect(linesYardstick.screenPositionForPixelPosition(top: Infinity, left: Infinity)).toEqual [12, 2]
        expect(linesYardstick.screenPositionForPixelPosition(top: (editor.getLastScreenRow() + 1) * 14, left: 0)).toEqual [12, 2]
        expect(linesYardstick.screenPositionForPixelPosition(top: editor.getLastScreenRow() * 14, left: 0)).toEqual [12, 0]
