LinesYardstick = require "../src/lines-yardstick"
{toArray} = require 'underscore-plus'

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
          return if availableScreenRows[lineId] isnt screenRow

          buildLineNode(screenRow)
        textNodesForLineIdAndScreenRow: (lineId, screenRow) ->
          lineNode = @lineNodeForLineIdAndScreenRow(lineId, screenRow)
          textNodes = []
          for span in lineNode.children
            for textNode in span.childNodes
              textNodes.push(textNode)
          textNodes

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
      expect(linesYardstick.pixelPositionForScreenPosition([0, 5])).toEqual({left: 37.8046875, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([1, 6])).toEqual({left: 43.20703125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([1, 9])).toEqual({left: 72.20703125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, Infinity])).toEqual({left: 288.046875, top: 28})

    it "reuses already computed pixel positions unless it is invalidated", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 16px;
        font-family: monospace;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 19.203125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 57.609375, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 95.609375, top: 70})

      atom.styles.addStyleSheet """
      * {
        font-size: 20px;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 19.203125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 57.609375, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 95.609375, top: 70})

      linesYardstick.invalidateCache()

      expect(linesYardstick.pixelPositionForScreenPosition([1, 2])).toEqual({left: 24.00390625, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition([2, 6])).toEqual({left: 72.01171875, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition([5, 10])).toEqual({left: 120.01171875, top: 70})

    it "correctly handles RTL characters", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 14px;
        font-family: monospace;
      }
      """

      editor.setText("السلام عليكم")
      expect(linesYardstick.pixelPositionForScreenPosition([0, 0]).left).toBe 0
      expect(linesYardstick.pixelPositionForScreenPosition([0, 1]).left).toBe 8
      expect(linesYardstick.pixelPositionForScreenPosition([0, 2]).left).toBe 16
      expect(linesYardstick.pixelPositionForScreenPosition([0, 5]).left).toBe 33
      expect(linesYardstick.pixelPositionForScreenPosition([0, 7]).left).toBe 50
      expect(linesYardstick.pixelPositionForScreenPosition([0, 9]).left).toBe 67
      expect(linesYardstick.pixelPositionForScreenPosition([0, 11]).left).toBe 84

    it "doesn't measure invisible lines if it is explicitly told so", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 12px;
        font-family: monospace;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition([0, 0], true, true)).toEqual({left: 0, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([0, 1], true, true)).toEqual({left: 0, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition([0, 5], true, true)).toEqual({left: 0, top: 0})

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
        expect(linesYardstick.screenPositionForPixelPosition({top: 14, left: 18.8})).toEqual([1, 3])
        expect(linesYardstick.screenPositionForPixelPosition({top: 28, left: 100})).toEqual([2, 14])
        expect(linesYardstick.screenPositionForPixelPosition({top: 32, left: 24.3})).toEqual([2, 3])
        expect(linesYardstick.screenPositionForPixelPosition({top: 46, left: 66.5})).toEqual([3, 9])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 99.9})).toEqual([5, 14])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 224.4365234375})).toEqual([5, 29])
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 225})).toEqual([5, 30])

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

      it "doesn't measure invisible lines if it is explicitly told so", ->
        atom.styles.addStyleSheet """
        * {
          font-size: 12px;
          font-family: monospace;
        }
        """

        expect(linesYardstick.screenPositionForPixelPosition({top: 0, left: 13}, true)).toEqual([0, 0])
        expect(linesYardstick.screenPositionForPixelPosition({top: 14, left: 20}, true)).toEqual([1, 0])
        expect(linesYardstick.screenPositionForPixelPosition({top: 28, left: 100}, true)).toEqual([2, 0])
