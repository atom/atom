LinesYardstick = require '../src/lines-yardstick'
LineTopIndex = require 'line-top-index'
{toArray} = require 'underscore-plus'
{Point} = require 'text-buffer'

describe "LinesYardstick", ->
  [editor, mockLineNodesProvider, createdLineNodes, linesYardstick, buildLineNode] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.workspace.open('sample.js').then (o) -> editor = o

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

      mockLineNodesProvider =
        lineNodeForLineIdAndScreenRow: (lineId, screenRow) ->
          buildLineNode(screenRow)

        textNodesForLineIdAndScreenRow: (lineId, screenRow) ->
          lineNode = @lineNodeForLineIdAndScreenRow(lineId, screenRow)
          iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT)
          textNodes = []
          while textNode = iterator.nextNode()
            textNodes.push(textNode)
          textNodes

      editor.setLineHeightInPixels(14)
      lineTopIndex = new LineTopIndex({
        defaultLineHeight: editor.getLineHeightInPixels()
      })
      linesYardstick = new LinesYardstick(editor, mockLineNodesProvider, lineTopIndex, atom.grammars)

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

      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 0))).toEqual({left: 0, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 1))).toEqual({left: 7, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 5))).toEqual({left: 37.78125, top: 0})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(1, 6))).toEqual({left: 43.171875, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(1, 9))).toEqual({left: 72.171875, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(2, Infinity))).toEqual({left: 287.859375, top: 28})

    it "reuses already computed pixel positions unless it is invalidated", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 16px;
        font-family: monospace;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition(Point(1, 2))).toEqual({left: 19.203125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(2, 6))).toEqual({left: 57.609375, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(5, 10))).toEqual({left: 95.609375, top: 70})

      atom.styles.addStyleSheet """
      * {
        font-size: 20px;
      }
      """

      expect(linesYardstick.pixelPositionForScreenPosition(Point(1, 2))).toEqual({left: 19.203125, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(2, 6))).toEqual({left: 57.609375, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(5, 10))).toEqual({left: 95.609375, top: 70})

      linesYardstick.invalidateCache()

      expect(linesYardstick.pixelPositionForScreenPosition(Point(1, 2))).toEqual({left: 24, top: 14})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(2, 6))).toEqual({left: 72, top: 28})
      expect(linesYardstick.pixelPositionForScreenPosition(Point(5, 10))).toEqual({left: 120, top: 70})

    it "correctly handles RTL characters", ->
      atom.styles.addStyleSheet """
      * {
        font-size: 14px;
        font-family: monospace;
      }
      """

      editor.setText("السلام عليكم")
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 0)).left).toBe 0
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 1)).left).toBe 8
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 2)).left).toBe 16
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 5)).left).toBe 33
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 7)).left).toBe 50
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 9)).left).toBe 67
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 11)).left).toBe 84

    it "doesn't report a width greater than 0 when the character to measure is at the beginning of a text node", ->
      # This spec documents what seems to be a bug in Chromium, because we'd
      # expect that Range(0, 0).getBoundingClientRect().width to always be zero.
      atom.styles.addStyleSheet """
      * {
        font-size: 11px;
        font-family: monospace;
      }
      """

      text = "    \\vec{w}_j^r(\\text{new}) &= \\vec{w}_j^r(\\text{old}) + \\Delta\\vec{w}_j^r, \\\\"
      buildLineNode = (screenRow) ->
        lineNode = document.createElement("div")
        lineNode.style.whiteSpace = "pre"
        # We couldn't reproduce the problem with a simple string, so we're
        # attaching the full one that comes from a bug report.
        lineNode.innerHTML = '<span><span>  </span><span>  </span><span><span>\\</span>vec</span><span><span>{</span>w<span>}</span></span>_j^r(<span><span>\\</span>text</span><span><span>{</span>new<span>}</span></span>) &amp;= <span><span>\\</span>vec</span><span><span>{</span>w<span>}</span></span>_j^r(<span><span>\\</span>text</span><span><span>{</span>old<span>}</span></span>) + <span><span>\\</span>Delta</span><span><span>\\</span>vec</span><span><span>{</span>w<span>}</span></span>_j^r, <span>\\\\</span></span>'
        jasmine.attachToDOM(lineNode)
        createdLineNodes.push(lineNode)
        lineNode

      editor.setText(text)

      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 35)).left).toBe 230.90625
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 36)).left).toBe 237.5
      expect(linesYardstick.pixelPositionForScreenPosition(Point(0, 37)).left).toBe 244.09375

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
        expect(linesYardstick.screenPositionForPixelPosition({top: 80, left: 224.2365234375})).toEqual([5, 29])
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
