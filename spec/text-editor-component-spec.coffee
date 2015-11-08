_ = require 'underscore-plus'
{extend, flatten, toArray, last} = _

TextEditorElement = require '../src/text-editor-element'
nbsp = String.fromCharCode(160)

describe "TextEditorComponent", ->
  [contentNode, editor, wrapperNode, component, componentNode, verticalScrollbarNode, horizontalScrollbarNode] = []
  [lineHeightInPixels, charWidth, tileSize, tileHeightInPixels] = []

  beforeEach ->
    tileSize = 3
    jasmine.useRealClock()

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.workspace.open('sample.js').then (o) -> editor = o

    runs ->
      contentNode = document.querySelector('#jasmine-content')
      contentNode.style.width = '1000px'

      wrapperNode = new TextEditorElement()
      wrapperNode.tileSize = tileSize
      wrapperNode.initialize(editor, atom)
      wrapperNode.setUpdatedSynchronously(false)
      jasmine.attachToDOM(wrapperNode)

      {component} = wrapperNode
      component.setFontFamily('monospace')
      component.setLineHeight(1.3)
      component.setFontSize(20)

      lineHeightInPixels = editor.getLineHeightInPixels()
      tileHeightInPixels = tileSize * lineHeightInPixels
      charWidth = editor.getDefaultCharWidth()
      componentNode = component.getDomNode()
      verticalScrollbarNode = componentNode.querySelector('.vertical-scrollbar')
      horizontalScrollbarNode = componentNode.querySelector('.horizontal-scrollbar')

      component.measureDimensions()
      waitsForNextDOMUpdate()

  afterEach ->
    contentNode.style.width = ''

  describe "async updates", ->
    it "handles corrupted state gracefully", ->
      # trigger state updates, e.g. presenter.updateLinesState
      editor.insertNewline()

      # simulate state corruption
      component.presenter.startRow = -1
      component.presenter.endRow = 9999
      waitsForNextDOMUpdate()

    it "doesn't update when an animation frame was requested but the component got destroyed before its delivery", ->
      editor.setText("You shouldn't see this update.")
      component.destroy()
      waitsForNextDOMUpdate()

      runs ->
        expect(component.lineNodeForScreenRow(0).textContent).not.toBe("You shouldn't see this update.")

  describe "line rendering", ->
    expectTileContainsRow = (tileNode, screenRow, {top}) ->
      lineNode = tileNode.querySelector("[data-screen-row='#{screenRow}']")
      tokenizedLine = editor.tokenizedLineForScreenRow(screenRow)

      expect(lineNode.offsetTop).toBe(top)
      if tokenizedLine.text is ""
        expect(lineNode.innerHTML).toBe("&nbsp;")
      else
        expect(lineNode.textContent).toBe(tokenizedLine.text)

    it "gives the lines container the same height as the wrapper node", ->
      linesNode = componentNode.querySelector(".lines")

      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(linesNode.getBoundingClientRect().height).toBe(6.5 * lineHeightInPixels)

        wrapperNode.style.height = 3.5 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(linesNode.getBoundingClientRect().height).toBe(3.5 * lineHeightInPixels)

    it "renders higher tiles in front of lower ones", ->
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(tilesNodes[0].style.zIndex).toBe("2")
        expect(tilesNodes[1].style.zIndex).toBe("1")
        expect(tilesNodes[2].style.zIndex).toBe("0")

        verticalScrollbarNode.scrollTop = 1 * lineHeightInPixels
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(tilesNodes[0].style.zIndex).toBe("3")
        expect(tilesNodes[1].style.zIndex).toBe("2")
        expect(tilesNodes[2].style.zIndex).toBe("1")
        expect(tilesNodes[3].style.zIndex).toBe("0")

    it "renders the currently-visible lines in a tiled fashion", ->
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(tilesNodes.length).toBe(3)

        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"
        expect(tilesNodes[0].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[0], 0, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 1, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 2, top: 2 * lineHeightInPixels)

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels}px, 0px)"
        expect(tilesNodes[1].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[1], 3, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 4, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 5, top: 2 * lineHeightInPixels)

        expect(tilesNodes[2].style['-webkit-transform']).toBe "translate3d(0px, #{2 * tileHeightInPixels}px, 0px)"
        expect(tilesNodes[2].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[2], 6, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 7, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 8, top: 2 * lineHeightInPixels)

        expect(component.lineNodeForScreenRow(9)).toBeUndefined()

        verticalScrollbarNode.scrollTop = tileSize * lineHeightInPixels + 5
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(component.lineNodeForScreenRow(2)).toBeUndefined()
        expect(tilesNodes.length).toBe(3)

        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, #{0 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[0].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[0], 3, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 4, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 5, top: 2 * lineHeightInPixels)

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[1].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[1], 6, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 7, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 8, top: 2 * lineHeightInPixels)

        expect(tilesNodes[2].style['-webkit-transform']).toBe "translate3d(0px, #{2 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[2].querySelectorAll(".line").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[2], 9, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 10, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 11, top: 2 * lineHeightInPixels)

    it "updates the top position of subsequent tiles when lines are inserted or removed", ->
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      editor.getBuffer().deleteRows(0, 1)
      waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"
        expectTileContainsRow(tilesNodes[0], 0, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 1, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 2, top: 2 * lineHeightInPixels)

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels}px, 0px)"
        expectTileContainsRow(tilesNodes[1], 3, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 4, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 5, top: 2 * lineHeightInPixels)

        editor.getBuffer().insert([0, 0], '\n\n')
        waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLines()

        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"
        expectTileContainsRow(tilesNodes[0], 0, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 1, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[0], 2, top: 2 * lineHeightInPixels)

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels}px, 0px)"
        expectTileContainsRow(tilesNodes[1], 3, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 4, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[1], 5, top: 2 * lineHeightInPixels)

        expect(tilesNodes[2].style['-webkit-transform']).toBe "translate3d(0px, #{2 * tileHeightInPixels}px, 0px)"
        expectTileContainsRow(tilesNodes[2], 6, top: 0 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 7, top: 1 * lineHeightInPixels)
        expectTileContainsRow(tilesNodes[2], 8, top: 2 * lineHeightInPixels)

    it "updates the lines when lines are inserted or removed above the rendered row range", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        verticalScrollbarNode.scrollTop = 5 * lineHeightInPixels
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      buffer = null
      runs ->
        buffer = editor.getBuffer()
        buffer.insert([0, 0], '\n\n')
        waitsForNextDOMUpdate()

      runs ->
        expect(component.lineNodeForScreenRow(3).textContent).toBe editor.tokenizedLineForScreenRow(3).text

        buffer.delete([[0, 0], [3, 0]])
        waitsForNextDOMUpdate()

      runs ->
        expect(component.lineNodeForScreenRow(3).textContent).toBe editor.tokenizedLineForScreenRow(3).text

    it "updates the top position of lines when the line height changes", ->
      initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setLineHeight(2)
      waitsForNextDOMUpdate()

      runs ->
        newLineHeightInPixels = editor.getLineHeightInPixels()
        expect(newLineHeightInPixels).not.toBe initialLineHeightInPixels
        expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * newLineHeightInPixels

    it "updates the top position of lines when the font size changes", ->
      initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setFontSize(10)
      waitsForNextDOMUpdate()

      runs ->
        newLineHeightInPixels = editor.getLineHeightInPixels()
        expect(newLineHeightInPixels).not.toBe initialLineHeightInPixels
        expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * newLineHeightInPixels

    it "renders the .lines div at the full height of the editor if there aren't enough lines to scroll vertically", ->
      editor.setText('')
      wrapperNode.style.height = '300px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        linesNode = componentNode.querySelector('.lines')
        expect(linesNode.offsetHeight).toBe 300

    it "assigns the width of each line so it extends across the full width of the editor", ->
      gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      scrollViewNode = componentNode.querySelector('.scroll-view')
      lineNodes = componentNode.querySelectorAll('.line')

      componentNode.style.width = gutterWidth + (30 * charWidth) + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(wrapperNode.getScrollWidth()).toBeGreaterThan scrollViewNode.offsetWidth

        # At the time of writing, using width: 100% to achieve the full-width
        # lines caused full-screen repaints after switching away from an editor
        # and back again Please ensure you don't cause a performance regression if
        # you change this behavior.
        editorFullWidth = wrapperNode.getScrollWidth() + wrapperNode.getVerticalScrollbarWidth()

        for lineNode in lineNodes
          expect(lineNode.getBoundingClientRect().width).toBe(editorFullWidth)

        componentNode.style.width = gutterWidth + wrapperNode.getScrollWidth() + 100 + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        scrollViewWidth = scrollViewNode.offsetWidth

        for lineNode in lineNodes
          expect(lineNode.getBoundingClientRect().width).toBe(scrollViewWidth)

    it "renders an nbsp on empty lines when no line-ending character is defined", ->
      atom.config.set("editor.showInvisibles", false)
      expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

    it "gives the lines and tiles divs the same background color as the editor to improve GPU performance", ->
      linesNode = componentNode.querySelector('.lines')
      backgroundColor = getComputedStyle(wrapperNode).backgroundColor
      expect(linesNode.style.backgroundColor).toBe backgroundColor

      for tileNode in component.tileNodesForLines()
        expect(tileNode.style.backgroundColor).toBe(backgroundColor)

      wrapperNode.style.backgroundColor = 'rgb(255, 0, 0)'
      waitsForNextDOMUpdate()

      runs ->
        expect(linesNode.style.backgroundColor).toBe 'rgb(255, 0, 0)'
        for tileNode in component.tileNodesForLines()
          expect(tileNode.style.backgroundColor).toBe("rgb(255, 0, 0)")

    it "applies .leading-whitespace for lines with leading spaces and/or tabs", ->
      editor.setText(' a')
      waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe false

        editor.setText('\ta')
        waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe false

    it "applies .trailing-whitespace for lines with trailing spaces and/or tabs", ->
      editor.setText(' ')
      waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

        editor.setText('\t')
        waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

        editor.setText('a ')
        waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

        editor.setText('a\t')
        waitsForNextDOMUpdate()

      runs ->
        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
        expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

    it "keeps rebuilding lines when continuous reflow is on", ->
      wrapperNode.setContinuousReflow(true)

      oldLineNodes = componentNode.querySelectorAll(".line")

      waits 300

      runs ->
        newLineNodes = componentNode.querySelectorAll(".line")
        expect(oldLineNodes).not.toEqual(newLineNodes)

        wrapperNode.setContinuousReflow(false)

    describe "when showInvisibles is enabled", ->
      invisibles = null

      beforeEach ->
        invisibles =
          eol: 'E'
          space: 'S'
          tab: 'T'
          cr: 'C'

        atom.config.set("editor.showInvisibles", true)
        atom.config.set("editor.invisibles", invisibles)
        waitsForNextDOMUpdate()

      it "re-renders the lines when the showInvisibles config option changes", ->
        editor.setText " a line with tabs\tand spaces \n"
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

          atom.config.set("editor.showInvisibles", false)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe " a line with tabs and spaces "

          atom.config.set("editor.showInvisibles", true)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

      it "displays leading/trailing spaces, tabs, and newlines as visible characters", ->
        editor.setText " a line with tabs\tand spaces \n"
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

          leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
          expect(leafNodes[0].classList.contains('invisible-character')).toBe true
          expect(leafNodes[leafNodes.length - 1].classList.contains('invisible-character')).toBe true

      it "displays newlines as their own token outside of the other tokens' scopeDescriptor", ->
        editor.setText "var\n"
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).innerHTML).toBe "<span class=\"source js\"><span class=\"storage modifier js\">var</span></span><span class=\"invisible-character\">#{invisibles.eol}</span>"

      it "displays trailing carriage returns using a visible, non-empty value", ->
        editor.setText "a line that ends with a carriage return\r\n"
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "a line that ends with a carriage return#{invisibles.cr}#{invisibles.eol}"

      it "renders invisible line-ending characters on empty lines", ->
        expect(component.lineNodeForScreenRow(10).textContent).toBe invisibles.eol

      it "renders an nbsp on empty lines when the line-ending character is an empty string", ->
        atom.config.set("editor.invisibles", eol: '')
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

      it "renders an nbsp on empty lines when the line-ending character is false", ->
        atom.config.set("editor.invisibles", eol: false)
        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

      it "interleaves invisible line-ending characters with indent guides on empty lines", ->
        atom.config.set "editor.showIndentGuide", true
        waitsForNextDOMUpdate()

        runs ->
          editor.setTextInBufferRange([[10, 0], [11, 0]], "\r\n", normalizeLineEndings: false)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span><span class="invisible-character">E</span></span>'

          editor.setTabLength(3)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span><span class="invisible-character">E</span> </span>'

          editor.setTabLength(1)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span></span><span class="indent-guide"><span class="invisible-character">E</span></span>'

          editor.setTextInBufferRange([[9, 0], [9, Infinity]], ' ')
          editor.setTextInBufferRange([[11, 0], [11, Infinity]], ' ')
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span></span><span class="invisible-character">E</span>'

      describe "when soft wrapping is enabled", ->
        beforeEach ->
          editor.setText "a line that wraps \n"
          editor.setSoftWrapped(true)
          waitsForNextDOMUpdate()
          runs ->
            componentNode.style.width = 16 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
            component.measureDimensions()
            waitsForNextDOMUpdate()

        it "doesn't show end of line invisibles at the end of wrapped lines", ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "a line that "
          expect(component.lineNodeForScreenRow(1).textContent).toBe "wraps#{invisibles.space}#{invisibles.eol}"

    describe "when indent guides are enabled", ->
      beforeEach ->
        atom.config.set "editor.showIndentGuide", true
        waitsForNextDOMUpdate()

      it "adds an 'indent-guide' class to spans comprising the leading whitespace", ->
        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

        line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
        expect(line2LeafNodes[0].textContent).toBe '  '
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[1].textContent).toBe '  '
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe false

      it "renders leading whitespace spans with the 'indent-guide' class for empty lines", ->
        editor.getBuffer().insert([1, Infinity], '\n')
        waitsForNextDOMUpdate()

        runs ->
          line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))

          expect(line2LeafNodes.length).toBe 2
          expect(line2LeafNodes[0].textContent).toBe '  '
          expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[1].textContent).toBe '  '
          expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true

      it "renders indent guides correctly on lines containing only whitespace", ->
        editor.getBuffer().insert([1, Infinity], '\n      ')
        waitsForNextDOMUpdate()

        runs ->
          line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
          expect(line2LeafNodes.length).toBe 3
          expect(line2LeafNodes[0].textContent).toBe '  '
          expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[1].textContent).toBe '  '
          expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[2].textContent).toBe '  '
          expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe true

      it "renders indent guides correctly on lines containing only whitespace when invisibles are enabled", ->
        atom.config.set 'editor.showInvisibles', true
        atom.config.set 'editor.invisibles', space: '-', eol: 'x'
        editor.getBuffer().insert([1, Infinity], '\n      ')

        waitsForNextDOMUpdate()

        runs ->
          line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
          expect(line2LeafNodes.length).toBe 4
          expect(line2LeafNodes[0].textContent).toBe '--'
          expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[1].textContent).toBe '--'
          expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[2].textContent).toBe '--'
          expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe true
          expect(line2LeafNodes[3].textContent).toBe 'x'

      it "does not render indent guides in trailing whitespace for lines containing non whitespace characters", ->
        editor.getBuffer().setText "  hi  "
        waitsForNextDOMUpdate()

        runs ->
          line0LeafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
          expect(line0LeafNodes[0].textContent).toBe '  '
          expect(line0LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line0LeafNodes[1].textContent).toBe '  '
          expect(line0LeafNodes[1].classList.contains('indent-guide')).toBe false

      it "updates the indent guides on empty lines preceding an indentation change", ->
        editor.getBuffer().insert([12, 0], '\n')
        waitsForNextDOMUpdate()

        runs ->
          editor.getBuffer().insert([13, 0], '    ')
          waitsForNextDOMUpdate()

        runs ->
          line12LeafNodes = getLeafNodes(component.lineNodeForScreenRow(12))
          expect(line12LeafNodes[0].textContent).toBe '  '
          expect(line12LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line12LeafNodes[1].textContent).toBe '  '
          expect(line12LeafNodes[1].classList.contains('indent-guide')).toBe true

      it "updates the indent guides on empty lines following an indentation change", ->
        editor.getBuffer().insert([12, 2], '\n')

        waitsForNextDOMUpdate()

        runs ->
          editor.getBuffer().insert([12, 0], '    ')
          waitsForNextDOMUpdate()

        runs ->
          line13LeafNodes = getLeafNodes(component.lineNodeForScreenRow(13))
          expect(line13LeafNodes[0].textContent).toBe '  '
          expect(line13LeafNodes[0].classList.contains('indent-guide')).toBe true
          expect(line13LeafNodes[1].textContent).toBe '  '
          expect(line13LeafNodes[1].classList.contains('indent-guide')).toBe true

    describe "when indent guides are disabled", ->
      beforeEach ->
        expect(atom.config.get("editor.showIndentGuide")).toBe false

      it "does not render indent guides on lines containing only whitespace", ->
        editor.getBuffer().insert([1, Infinity], '\n      ')

        waitsForNextDOMUpdate()

        runs ->
          line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))
          expect(line2LeafNodes.length).toBe 3
          expect(line2LeafNodes[0].textContent).toBe '  '
          expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe false
          expect(line2LeafNodes[1].textContent).toBe '  '
          expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe false
          expect(line2LeafNodes[2].textContent).toBe '  '
          expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe false

    describe "when the buffer contains null bytes", ->
      it "excludes the null byte from character measurement", ->
        editor.setText("a\0b")

        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.pixelPositionForScreenPosition([0, Infinity]).left).toEqual 2 * charWidth

    describe "when there is a fold", ->
      it "renders a fold marker on the folded line", ->
        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()

        editor.foldBufferRow(4)
        waitsForNextDOMUpdate()

        runs ->
          foldedLineNode = component.lineNodeForScreenRow(4)
          expect(foldedLineNode.querySelector('.fold-marker')).toBeTruthy()

          editor.unfoldBufferRow(4)
          waitsForNextDOMUpdate()

        runs ->
          foldedLineNode = component.lineNodeForScreenRow(4)
          expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()

  describe "gutter rendering", ->
    expectTileContainsRow = (tileNode, screenRow, {top, text}) ->
      lineNode = tileNode.querySelector("[data-screen-row='#{screenRow}']")

      expect(lineNode.offsetTop).toBe(top)
      expect(lineNode.textContent).toBe(text)

    it "renders higher tiles in front of lower ones", ->
      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLineNumbers()

        expect(tilesNodes[0].style.zIndex).toBe("2")
        expect(tilesNodes[1].style.zIndex).toBe("1")
        expect(tilesNodes[2].style.zIndex).toBe("0")

        verticalScrollbarNode.scrollTop = 1 * lineHeightInPixels
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLineNumbers()

        expect(tilesNodes[0].style.zIndex).toBe("3")
        expect(tilesNodes[1].style.zIndex).toBe("2")
        expect(tilesNodes[2].style.zIndex).toBe("1")
        expect(tilesNodes[3].style.zIndex).toBe("0")

    it "gives the line numbers container the same height as the wrapper node", ->
      linesNode = componentNode.querySelector(".line-numbers")

      wrapperNode.style.height = 6.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(linesNode.getBoundingClientRect().height).toBe(6.5 * lineHeightInPixels)

        wrapperNode.style.height = 3.5 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(linesNode.getBoundingClientRect().height).toBe(3.5 * lineHeightInPixels)

    it "renders the currently-visible line numbers in a tiled fashion", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLineNumbers()

        expect(tilesNodes.length).toBe(3)
        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"

        expect(tilesNodes[0].querySelectorAll('.line-number').length).toBe 3
        expectTileContainsRow(tilesNodes[0], 0, top: lineHeightInPixels * 0, text: "#{nbsp}1")
        expectTileContainsRow(tilesNodes[0], 1, top: lineHeightInPixels * 1, text: "#{nbsp}2")
        expectTileContainsRow(tilesNodes[0], 2, top: lineHeightInPixels * 2, text: "#{nbsp}3")

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels}px, 0px)"
        expect(tilesNodes[1].querySelectorAll('.line-number').length).toBe 3
        expectTileContainsRow(tilesNodes[1], 3, top: lineHeightInPixels * 0, text: "#{nbsp}4")
        expectTileContainsRow(tilesNodes[1], 4, top: lineHeightInPixels * 1, text: "#{nbsp}5")
        expectTileContainsRow(tilesNodes[1], 5, top: lineHeightInPixels * 2, text: "#{nbsp}6")

        expect(tilesNodes[2].style['-webkit-transform']).toBe "translate3d(0px, #{2 * tileHeightInPixels}px, 0px)"
        expect(tilesNodes[2].querySelectorAll('.line-number').length).toBe 3
        expectTileContainsRow(tilesNodes[2], 6, top: lineHeightInPixels * 0, text: "#{nbsp}7")
        expectTileContainsRow(tilesNodes[2], 7, top: lineHeightInPixels * 1, text: "#{nbsp}8")
        expectTileContainsRow(tilesNodes[2], 8, top: lineHeightInPixels * 2, text: "#{nbsp}9")

        verticalScrollbarNode.scrollTop = tileSize * lineHeightInPixels + 5
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        tilesNodes = component.tileNodesForLineNumbers()

        expect(component.lineNumberNodeForScreenRow(2)).toBeUndefined()
        expect(tilesNodes.length).toBe(3)

        expect(tilesNodes[0].style['-webkit-transform']).toBe "translate3d(0px, #{0 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[0].querySelectorAll(".line-number").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[0], 3, top: lineHeightInPixels * 0, text: "#{nbsp}4")
        expectTileContainsRow(tilesNodes[0], 4, top: lineHeightInPixels * 1, text: "#{nbsp}5")
        expectTileContainsRow(tilesNodes[0], 5, top: lineHeightInPixels * 2, text: "#{nbsp}6")

        expect(tilesNodes[1].style['-webkit-transform']).toBe "translate3d(0px, #{1 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[1].querySelectorAll(".line-number").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[1], 6, top: 0 * lineHeightInPixels, text: "#{nbsp}7")
        expectTileContainsRow(tilesNodes[1], 7, top: 1 * lineHeightInPixels, text: "#{nbsp}8")
        expectTileContainsRow(tilesNodes[1], 8, top: 2 * lineHeightInPixels, text: "#{nbsp}9")

        expect(tilesNodes[2].style['-webkit-transform']).toBe "translate3d(0px, #{2 * tileHeightInPixels - 5}px, 0px)"
        expect(tilesNodes[2].querySelectorAll(".line-number").length).toBe(tileSize)
        expectTileContainsRow(tilesNodes[2], 9, top: 0 * lineHeightInPixels, text: "10")
        expectTileContainsRow(tilesNodes[2], 10, top: 1 * lineHeightInPixels, text: "11")
        expectTileContainsRow(tilesNodes[2], 11, top: 2 * lineHeightInPixels, text: "12")

    it "updates the translation of subsequent line numbers when lines are inserted or removed", ->
      editor.getBuffer().insert([0, 0], '\n\n')
      waitsForNextDOMUpdate()

      runs ->
        lineNumberNodes = componentNode.querySelectorAll('.line-number')
        expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe 0 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe 0 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe 1 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(5).offsetTop).toBe 2 * lineHeightInPixels

        editor.getBuffer().insert([0, 0], '\n\n')
        waitsForNextDOMUpdate()

      runs ->
        expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe 0 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe 0 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe 1 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(5).offsetTop).toBe 2 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(6).offsetTop).toBe 0 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(7).offsetTop).toBe 1 * lineHeightInPixels
        expect(component.lineNumberNodeForScreenRow(8).offsetTop).toBe 2 * lineHeightInPixels

    it "renders • characters for soft-wrapped lines", ->
      editor.setSoftWrapped(true)
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelectorAll('.line-number').length).toBe 9 + 1 # 3 line-numbers tiles + 1 dummy line
        expect(component.lineNumberNodeForScreenRow(0).textContent).toBe "#{nbsp}1"
        expect(component.lineNumberNodeForScreenRow(1).textContent).toBe "#{nbsp}•"
        expect(component.lineNumberNodeForScreenRow(2).textContent).toBe "#{nbsp}2"
        expect(component.lineNumberNodeForScreenRow(3).textContent).toBe "#{nbsp}•"
        expect(component.lineNumberNodeForScreenRow(4).textContent).toBe "#{nbsp}3"
        expect(component.lineNumberNodeForScreenRow(5).textContent).toBe "#{nbsp}•"
        expect(component.lineNumberNodeForScreenRow(6).textContent).toBe "#{nbsp}4"
        expect(component.lineNumberNodeForScreenRow(7).textContent).toBe "#{nbsp}•"
        expect(component.lineNumberNodeForScreenRow(8).textContent).toBe "#{nbsp}•"

    it "pads line numbers to be right-justified based on the maximum number of line number digits", ->
      editor.getBuffer().setText([1..10].join('\n'))

      waitsForNextDOMUpdate()

      [gutterNode, initialGutterWidth] = []

      runs ->
        for screenRow in [0..8]
          expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{nbsp}#{screenRow + 1}"
        expect(component.lineNumberNodeForScreenRow(9).textContent).toBe "10"

        gutterNode = componentNode.querySelector('.gutter')
        initialGutterWidth = gutterNode.offsetWidth

        # Removes padding when the max number of digits goes down
        editor.getBuffer().delete([[1, 0], [2, 0]])
        waitsForNextDOMUpdate()

      runs ->
        for screenRow in [0..8]
          expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{screenRow + 1}"
        expect(gutterNode.offsetWidth).toBeLessThan initialGutterWidth

        # Increases padding when the max number of digits goes up
        editor.getBuffer().insert([0, 0], '\n\n')
        waitsForNextDOMUpdate()

      runs ->
        for screenRow in [0..8]
          expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{nbsp}#{screenRow + 1}"
        expect(component.lineNumberNodeForScreenRow(9).textContent).toBe "10"
        expect(gutterNode.offsetWidth).toBe initialGutterWidth

    it "renders the .line-numbers div at the full height of the editor even if it's taller than its content", ->
      wrapperNode.style.height = componentNode.offsetHeight + 100 + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.line-numbers').offsetHeight).toBe componentNode.offsetHeight

    it "applies the background color of the gutter or the editor to the line numbers to improve GPU performance", ->
      gutterNode = componentNode.querySelector('.gutter')
      lineNumbersNode = gutterNode.querySelector('.line-numbers')
      {backgroundColor} = getComputedStyle(wrapperNode)
      expect(lineNumbersNode.style.backgroundColor).toBe backgroundColor
      for tileNode in component.tileNodesForLineNumbers()
        expect(tileNode.style.backgroundColor).toBe(backgroundColor)

      # favor gutter color if it's assigned
      gutterNode.style.backgroundColor = 'rgb(255, 0, 0)'
      atom.views.performDocumentPoll() # required due to DOM change not being detected inside shadow DOM
      waitsForNextDOMUpdate()

      runs ->
        expect(lineNumbersNode.style.backgroundColor).toBe 'rgb(255, 0, 0)'
        for tileNode in component.tileNodesForLineNumbers()
          expect(tileNode.style.backgroundColor).toBe("rgb(255, 0, 0)")

    it "hides or shows the gutter based on the '::isLineNumberGutterVisible' property on the model and the global 'editor.showLineNumbers' config setting", ->
      expect(component.gutterContainerComponent.getLineNumberGutterComponent()?).toBe true

      editor.setLineNumberGutterVisible(false)
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.gutter').style.display).toBe 'none'

        atom.config.set("editor.showLineNumbers", false)
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.gutter').style.display).toBe 'none'

        editor.setLineNumberGutterVisible(true)
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.gutter').style.display).toBe 'none'

        atom.config.set("editor.showLineNumbers", true)
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.gutter').style.display).toBe ''
        expect(component.lineNumberNodeForScreenRow(3)?).toBe true

    it "keeps rebuilding line numbers when continuous reflow is on", ->
      wrapperNode.setContinuousReflow(true)

      oldLineNodes = componentNode.querySelectorAll(".line-number")

      waits 300

      runs ->
        newLineNodes = componentNode.querySelectorAll(".line-number")
        expect(oldLineNodes).not.toEqual(newLineNodes)

    describe "fold decorations", ->
      describe "rendering fold decorations", ->
        it "adds the foldable class to line numbers when the line is foldable", ->
          expect(lineNumberHasClass(0, 'foldable')).toBe true
          expect(lineNumberHasClass(1, 'foldable')).toBe true
          expect(lineNumberHasClass(2, 'foldable')).toBe false
          expect(lineNumberHasClass(3, 'foldable')).toBe false
          expect(lineNumberHasClass(4, 'foldable')).toBe true
          expect(lineNumberHasClass(5, 'foldable')).toBe false

        it "updates the foldable class on the correct line numbers when the foldable positions change", ->
          editor.getBuffer().insert([0, 0], '\n')
          waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(0, 'foldable')).toBe false
            expect(lineNumberHasClass(1, 'foldable')).toBe true
            expect(lineNumberHasClass(2, 'foldable')).toBe true
            expect(lineNumberHasClass(3, 'foldable')).toBe false
            expect(lineNumberHasClass(4, 'foldable')).toBe false
            expect(lineNumberHasClass(5, 'foldable')).toBe true
            expect(lineNumberHasClass(6, 'foldable')).toBe false

        it "updates the foldable class on a line number that becomes foldable", ->
          expect(lineNumberHasClass(11, 'foldable')).toBe false

          editor.getBuffer().insert([11, 44], '\n    fold me')
          waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(11, 'foldable')).toBe true
            editor.undo()
            waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(11, 'foldable')).toBe false

        it "adds, updates and removes the folded class on the correct line number componentNodes", ->
          editor.foldBufferRow(4)
          waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(4, 'folded')).toBe true
            editor.getBuffer().insert([0, 0], '\n')
            waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(4, 'folded')).toBe false
            expect(lineNumberHasClass(5, 'folded')).toBe true

            editor.unfoldBufferRow(5)
            waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(5, 'folded')).toBe false

        describe "when soft wrapping is enabled", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            waitsForNextDOMUpdate()

            runs ->
              componentNode.style.width = 16 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
              component.measureDimensions()
              waitsForNextDOMUpdate()

          it "doesn't add the foldable class for soft-wrapped lines", ->
            expect(lineNumberHasClass(0, 'foldable')).toBe true
            expect(lineNumberHasClass(1, 'foldable')).toBe false

      describe "mouse interactions with fold indicators", ->
        [gutterNode] = []

        buildClickEvent = (target) ->
          buildMouseEvent('click', {target})

        beforeEach ->
          gutterNode = componentNode.querySelector('.gutter')

        describe "when the component is destroyed", ->
          it "stops listening for folding events", ->
            component.destroy()

            lineNumber = component.lineNumberNodeForScreenRow(1)
            target = lineNumber.querySelector('.icon-right')
            target.dispatchEvent(buildClickEvent(target))

        it "folds and unfolds the block represented by the fold indicator when clicked", ->
          expect(lineNumberHasClass(1, 'folded')).toBe false

          lineNumber = component.lineNumberNodeForScreenRow(1)
          target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))
          waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(1, 'folded')).toBe true

            lineNumber = component.lineNumberNodeForScreenRow(1)
            target = lineNumber.querySelector('.icon-right')
            target.dispatchEvent(buildClickEvent(target))
            waitsForNextDOMUpdate()

          runs ->
            expect(lineNumberHasClass(1, 'folded')).toBe false

        it "does not fold when the line number componentNode is clicked", ->
          lineNumber = component.lineNumberNodeForScreenRow(1)
          lineNumber.dispatchEvent(buildClickEvent(lineNumber))
          waits 100
          runs ->
            expect(lineNumberHasClass(1, 'folded')).toBe false

  describe "cursor rendering", ->
    it "renders the currently visible cursors", ->
      [cursor1, cursor2, cursor3, cursorNodes] = []

      cursor1 = editor.getLastCursor()
      cursor1.setScreenPosition([0, 5], autoscroll: false)

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        cursorNodes = componentNode.querySelectorAll('.cursor')
        expect(cursorNodes.length).toBe 1
        expect(cursorNodes[0].offsetHeight).toBe lineHeightInPixels
        expect(cursorNodes[0].offsetWidth).toBeCloseTo charWidth, 0
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(5 * charWidth)}px, #{0 * lineHeightInPixels}px)"

        cursor2 = editor.addCursorAtScreenPosition([8, 11], autoscroll: false)
        cursor3 = editor.addCursorAtScreenPosition([4, 10], autoscroll: false)
        waitsForNextDOMUpdate()

      runs ->
        cursorNodes = componentNode.querySelectorAll('.cursor')
        expect(cursorNodes.length).toBe 2
        expect(cursorNodes[0].offsetTop).toBe 0
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(5 * charWidth)}px, #{0 * lineHeightInPixels}px)"
        expect(cursorNodes[1].style['-webkit-transform']).toBe "translate(#{Math.round(10 * charWidth)}px, #{4 * lineHeightInPixels}px)"

        verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
        waitsForNextDOMUpdate()

      runs ->
        horizontalScrollbarNode.scrollLeft = 3.5 * charWidth
        waitsForNextDOMUpdate()

      cursorMovedListener = null
      runs ->
        cursorNodes = componentNode.querySelectorAll('.cursor')
        expect(cursorNodes.length).toBe 2
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(10 * charWidth - horizontalScrollbarNode.scrollLeft)}px, #{4 * lineHeightInPixels - verticalScrollbarNode.scrollTop}px)"
        expect(cursorNodes[1].style['-webkit-transform']).toBe "translate(#{Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)}px, #{8 * lineHeightInPixels - verticalScrollbarNode.scrollTop}px)"

        editor.onDidChangeCursorPosition cursorMovedListener = jasmine.createSpy('cursorMovedListener')
        cursor3.setScreenPosition([4, 11], autoscroll: false)
        waitsForNextDOMUpdate()

      runs ->
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)}px, #{4 * lineHeightInPixels - verticalScrollbarNode.scrollTop}px)"
        expect(cursorMovedListener).toHaveBeenCalled()

        cursor3.destroy()
        waitsForNextDOMUpdate()

      runs ->
        cursorNodes = componentNode.querySelectorAll('.cursor')

        expect(cursorNodes.length).toBe 1
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(11 * charWidth - horizontalScrollbarNode.scrollLeft)}px, #{8 * lineHeightInPixels - verticalScrollbarNode.scrollTop}px)"

    it "accounts for character widths when positioning cursors", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setCursorScreenPosition([0, 16])
      waitsForNextDOMUpdate()

      runs ->
        cursor = componentNode.querySelector('.cursor')
        cursorRect = cursor.getBoundingClientRect()

        cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.storage.type.function.js').firstChild
        range = document.createRange()
        range.setStart(cursorLocationTextNode, 0)
        range.setEnd(cursorLocationTextNode, 1)
        rangeRect = range.getBoundingClientRect()

        expect(cursorRect.left).toBeCloseTo rangeRect.left, 0
        expect(cursorRect.width).toBeCloseTo rangeRect.width, 0

    it "accounts for the width of paired characters when positioning cursors", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setText('he\u0301y') # e with an accent mark
      editor.setCursorBufferPosition([0, 3])
      waitsForNextDOMUpdate()

      runs ->
        cursor = componentNode.querySelector('.cursor')
        cursorRect = cursor.getBoundingClientRect()

        cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.source.js').childNodes[2]

        range = document.createRange()
        range.setStart(cursorLocationTextNode, 0)
        range.setEnd(cursorLocationTextNode, 1)
        rangeRect = range.getBoundingClientRect()

        expect(cursorRect.left).toBeCloseTo rangeRect.left, 0
        expect(cursorRect.width).toBeCloseTo rangeRect.width, 0

    it "positions cursors correctly after character widths are changed via a stylesheet change", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setCursorScreenPosition([0, 16])
      waitsForNextDOMUpdate()

      runs ->
        atom.styles.addStyleSheet """
          .function.js {
            font-weight: bold;
          }
        """, context: 'atom-text-editor'
        waitsForNextDOMUpdate()

      runs ->
        cursor = componentNode.querySelector('.cursor')
        cursorRect = cursor.getBoundingClientRect()

        cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.storage.type.function.js').firstChild
        range = document.createRange()
        range.setStart(cursorLocationTextNode, 0)
        range.setEnd(cursorLocationTextNode, 1)
        rangeRect = range.getBoundingClientRect()

        expect(cursorRect.left).toBeCloseTo rangeRect.left, 0
        expect(cursorRect.width).toBeCloseTo rangeRect.width, 0

        atom.themes.removeStylesheet('test')

    it "sets the cursor to the default character width at the end of a line", ->
      editor.setCursorScreenPosition([0, Infinity])
      waitsForNextDOMUpdate()

      runs ->
        cursorNode = componentNode.querySelector('.cursor')
        expect(cursorNode.offsetWidth).toBeCloseTo charWidth, 0

    it "gives the cursor a non-zero width even if it's inside atomic tokens", ->
      editor.setCursorScreenPosition([1, 0])
      waitsForNextDOMUpdate()

      runs ->
        cursorNode = componentNode.querySelector('.cursor')
        expect(cursorNode.offsetWidth).toBeCloseTo charWidth, 0

    it "blinks cursors when they aren't moving", ->
      cursorsNode = componentNode.querySelector('.cursors')
      wrapperNode.focus()
      waitsForNextDOMUpdate()

      runs -> expect(cursorsNode.classList.contains('blink-off')).toBe false

      waitsFor -> cursorsNode.classList.contains('blink-off')
      waitsFor -> not cursorsNode.classList.contains('blink-off')

      runs ->
        # Stop blinking after moving the cursor
        editor.moveRight()
        waitsForNextDOMUpdate()

      runs ->
        expect(cursorsNode.classList.contains('blink-off')).toBe false

      waitsFor -> cursorsNode.classList.contains('blink-off')

    it "does not render cursors that are associated with non-empty selections", ->
      editor.setSelectedScreenRange([[0, 4], [4, 6]])
      editor.addCursorAtScreenPosition([6, 8])
      waitsForNextDOMUpdate()

      runs ->
        cursorNodes = componentNode.querySelectorAll('.cursor')
        expect(cursorNodes.length).toBe 1
        expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{Math.round(8 * charWidth)}px, #{6 * lineHeightInPixels}px)"

    it "updates cursor positions when the line height changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setLineHeight(2)
      waitsForNextDOMUpdate()

      runs ->
        cursorNode = componentNode.querySelector('.cursor')
        expect(cursorNode.style['-webkit-transform']).toBe "translate(#{Math.round(10 * editor.getDefaultCharWidth())}px, #{editor.getLineHeightInPixels()}px)"

    it "updates cursor positions when the font size changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setFontSize(10)
      waitsForNextDOMUpdate()

      runs ->
        cursorNode = componentNode.querySelector('.cursor')
        expect(cursorNode.style['-webkit-transform']).toBe "translate(#{Math.round(10 * editor.getDefaultCharWidth())}px, #{editor.getLineHeightInPixels()}px)"

    it "updates cursor positions when the font family changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setFontFamily('sans-serif')
      waitsForNextDOMUpdate()

      runs ->
        cursorNode = componentNode.querySelector('.cursor')

        {left} = wrapperNode.pixelPositionForScreenPosition([1, 10])
        expect(cursorNode.style['-webkit-transform']).toBe "translate(#{Math.round(left)}px, #{editor.getLineHeightInPixels()}px)"

  describe "selection rendering", ->
    [scrollViewNode, scrollViewClientLeft] = []

    beforeEach ->
      scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left

    it "renders 1 region for 1-line selections", ->
      # 1-line selection
      editor.setSelectedScreenRange([[1, 6], [1, 10]])
      waitsForNextDOMUpdate()

      runs ->
        regions = componentNode.querySelectorAll('.selection .region')

        expect(regions.length).toBe 1
        regionRect = regions[0].getBoundingClientRect()
        expect(regionRect.top).toBe 1 * lineHeightInPixels
        expect(regionRect.height).toBe 1 * lineHeightInPixels
        expect(regionRect.left).toBeCloseTo scrollViewClientLeft + 6 * charWidth, 0
        expect(regionRect.width).toBeCloseTo 4 * charWidth, 0

    it "renders 2 regions for 2-line selections", ->
      editor.setSelectedScreenRange([[1, 6], [2, 10]])
      waitsForNextDOMUpdate()

      runs ->
        tileNode = component.tileNodesForLines()[0]
        regions = tileNode.querySelectorAll('.selection .region')
        expect(regions.length).toBe 2

        region1Rect = regions[0].getBoundingClientRect()
        expect(region1Rect.top).toBe 1 * lineHeightInPixels
        expect(region1Rect.height).toBe 1 * lineHeightInPixels
        expect(region1Rect.left).toBeCloseTo scrollViewClientLeft + 6 * charWidth, 0
        expect(region1Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        region2Rect = regions[1].getBoundingClientRect()
        expect(region2Rect.top).toBe 2 * lineHeightInPixels
        expect(region2Rect.height).toBe 1 * lineHeightInPixels
        expect(region2Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region2Rect.width).toBeCloseTo 10 * charWidth, 0

    it "renders 3 regions per tile for selections with more than 2 lines", ->
      editor.setSelectedScreenRange([[0, 6], [5, 10]])
      waitsForNextDOMUpdate()

      runs ->
        # Tile 0
        tileNode = component.tileNodesForLines()[0]
        regions = tileNode.querySelectorAll('.selection .region')
        expect(regions.length).toBe(3)

        region1Rect = regions[0].getBoundingClientRect()
        expect(region1Rect.top).toBe 0
        expect(region1Rect.height).toBe 1 * lineHeightInPixels
        expect(region1Rect.left).toBeCloseTo scrollViewClientLeft + 6 * charWidth, 0
        expect(region1Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        region2Rect = regions[1].getBoundingClientRect()
        expect(region2Rect.top).toBe 1 * lineHeightInPixels
        expect(region2Rect.height).toBe 1 * lineHeightInPixels
        expect(region2Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region2Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        region3Rect = regions[2].getBoundingClientRect()
        expect(region3Rect.top).toBe 2 * lineHeightInPixels
        expect(region3Rect.height).toBe 1 * lineHeightInPixels
        expect(region3Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region3Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        # Tile 3
        tileNode = component.tileNodesForLines()[1]
        regions = tileNode.querySelectorAll('.selection .region')
        expect(regions.length).toBe(3)

        region1Rect = regions[0].getBoundingClientRect()
        expect(region1Rect.top).toBe 3 * lineHeightInPixels
        expect(region1Rect.height).toBe 1 * lineHeightInPixels
        expect(region1Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region1Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        region2Rect = regions[1].getBoundingClientRect()
        expect(region2Rect.top).toBe 4 * lineHeightInPixels
        expect(region2Rect.height).toBe 1 * lineHeightInPixels
        expect(region2Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region2Rect.right).toBeCloseTo tileNode.getBoundingClientRect().right, 0

        region3Rect = regions[2].getBoundingClientRect()
        expect(region3Rect.top).toBe 5 * lineHeightInPixels
        expect(region3Rect.height).toBe 1 * lineHeightInPixels
        expect(region3Rect.left).toBeCloseTo scrollViewClientLeft + 0, 0
        expect(region3Rect.width).toBeCloseTo 10 * charWidth, 0

    it "does not render empty selections", ->
      editor.addSelectionForBufferRange([[2, 2], [2, 2]])
      waitsForNextDOMUpdate()

      runs ->
        expect(editor.getSelections()[0].isEmpty()).toBe true
        expect(editor.getSelections()[1].isEmpty()).toBe true

        expect(componentNode.querySelectorAll('.selection').length).toBe 0

    it "updates selections when the line height changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setLineHeight(2)
      waitsForNextDOMUpdate()

      runs ->
        selectionNode = componentNode.querySelector('.region')
        expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()

    it "updates selections when the font size changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontSize(10)
      waitsForNextDOMUpdate()

      runs ->
        selectionNode = componentNode.querySelector('.region')
        expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()
        expect(selectionNode.offsetLeft).toBeCloseTo 6 * editor.getDefaultCharWidth(), 0

    it "updates selections when the font family changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontFamily('sans-serif')
      waitsForNextDOMUpdate()

      runs ->
        selectionNode = componentNode.querySelector('.region')
        expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()
        expect(selectionNode.offsetLeft).toBeCloseTo wrapperNode.pixelPositionForScreenPosition([1, 6]).left, 0

    it "will flash the selection when flash:true is passed to editor::setSelectedBufferRange", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]], flash: true)
      waitsForNextDOMUpdate()

      selectionNode = null
      runs ->
        selectionNode = componentNode.querySelector('.selection')
        expect(selectionNode.classList.contains('flash')).toBe true

      waitsFor -> not selectionNode.classList.contains('flash')

      runs ->
        editor.setSelectedBufferRange([[1, 5], [1, 7]], flash: true)
        waitsForNextDOMUpdate()

      runs ->
        expect(selectionNode.classList.contains('flash')).toBe true

  describe "line decoration rendering", ->
    [marker, decoration, decorationParams] = []

    beforeEach ->
      marker = editor.displayBuffer.markBufferRange([[2, 13], [3, 15]], invalidate: 'inside', maintainHistory: true)
      decorationParams = {type: ['line-number', 'line'], class: 'a'}
      decoration = editor.decorateMarker(marker, decorationParams)
      waitsForNextDOMUpdate()

    it "applies line decoration classes to lines and line numbers", ->
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true

      # Shrink editor vertically
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        # Add decorations that are out of range
        marker2 = editor.displayBuffer.markBufferRange([[9, 0], [9, 0]])
        editor.decorateMarker(marker2, type: ['line-number', 'line'], class: 'b')
        waitsForNextDOMUpdate()

      runs ->
        # Scroll decorations into view
        verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        expect(lineAndLineNumberHaveClass(9, 'b')).toBe true

        # Fold a line to move the decorations
        editor.foldBufferRow(5)
        waitsForNextDOMUpdate()

      runs ->
        expect(lineAndLineNumberHaveClass(9, 'b')).toBe false
        expect(lineAndLineNumberHaveClass(6, 'b')).toBe true

    it "only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
      editor.setText("a line that wraps, ok")
      editor.setSoftWrapped(true)
      componentNode.style.width = 16 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        marker.destroy()
        marker = editor.markBufferRange([[0, 0], [0, 2]])
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'b')
        waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(0, 'b')).toBe true
        expect(lineNumberHasClass(1, 'b')).toBe false

        marker.setBufferRange([[0, 0], [0, Infinity]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(0, 'b')).toBe true
        expect(lineNumberHasClass(1, 'b')).toBe true

    it "updates decorations when markers move", ->
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

      editor.getBuffer().insert([0, 0], '\n')
      waitsForNextDOMUpdate()

      runs ->
        expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(4, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(5, 'a')).toBe false

        marker.setBufferRange([[4, 4], [6, 4]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(4, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(5, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(6, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(7, 'a')).toBe false

    it "remove decoration classes when decorations are removed", ->
      decoration.destroy()
      waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(1, 'a')).toBe false
        expect(lineNumberHasClass(2, 'a')).toBe false
        expect(lineNumberHasClass(3, 'a')).toBe false
        expect(lineNumberHasClass(4, 'a')).toBe false

    it "removes decorations when their marker is invalidated", ->
      editor.getBuffer().insert([3, 2], 'n')
      waitsForNextDOMUpdate()

      runs ->
        expect(marker.isValid()).toBe false
        expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

        editor.undo()
        waitsForNextDOMUpdate()

      runs ->
        expect(marker.isValid()).toBe true
        expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
        expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
        expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

    it "removes decorations when their marker is destroyed", ->
      marker.destroy()
      waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(1, 'a')).toBe false
        expect(lineNumberHasClass(2, 'a')).toBe false
        expect(lineNumberHasClass(3, 'a')).toBe false
        expect(lineNumberHasClass(4, 'a')).toBe false

    describe "when the decoration's 'onlyHead' property is true", ->
      it "only applies the decoration's class to lines containing the marker's head", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-head', onlyHead: true)
        waitsForNextDOMUpdate()

        runs ->
          expect(lineAndLineNumberHaveClass(1, 'only-head')).toBe false
          expect(lineAndLineNumberHaveClass(2, 'only-head')).toBe false
          expect(lineAndLineNumberHaveClass(3, 'only-head')).toBe true
          expect(lineAndLineNumberHaveClass(4, 'only-head')).toBe false

    describe "when the decoration's 'onlyEmpty' property is true", ->
      it "only applies the decoration when its marker is empty", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-empty', onlyEmpty: true)
        waitsForNextDOMUpdate()

        runs ->
          expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe false
          expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe false

          marker.clearTail()
          waitsForNextDOMUpdate()

        runs ->
          expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe false
          expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe true

    describe "when the decoration's 'onlyNonEmpty' property is true", ->
      it "only applies the decoration when its marker is non-empty", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-non-empty', onlyNonEmpty: true)
        waitsForNextDOMUpdate()

        runs ->
          expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe true
          expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe true

          marker.clearTail()
          waitsForNextDOMUpdate()

        runs ->
          expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe false
          expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe false

  describe "highlight decoration rendering", ->
    [marker, decoration, decorationParams, scrollViewClientLeft] = []
    beforeEach ->
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left
      marker = editor.displayBuffer.markBufferRange([[2, 13], [3, 15]], invalidate: 'inside', maintainHistory: true)
      decorationParams = {type: 'highlight', class: 'test-highlight'}
      decoration = editor.decorateMarker(marker, decorationParams)
      waitsForNextDOMUpdate()

    it "does not render highlights for off-screen lines until they come on-screen", ->
      wrapperNode.style.height = 2.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        marker = editor.displayBuffer.markBufferRange([[9, 2], [9, 4]], invalidate: 'inside')
        editor.decorateMarker(marker, type: 'highlight', class: 'some-highlight')
        waitsForNextDOMUpdate()

      runs ->
        # Should not be rendering range containing the marker
        expect(component.presenter.endRow).toBeLessThan 9

        regions = componentNode.querySelectorAll('.some-highlight .region')

        # Nothing when outside the rendered row range
        expect(regions.length).toBe 0

        verticalScrollbarNode.scrollTop = 6 * lineHeightInPixels
        verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        expect(component.presenter.endRow).toBeGreaterThan(8)

        regions = componentNode.querySelectorAll('.some-highlight .region')

        expect(regions.length).toBe 1
        regionRect = regions[0].style
        expect(regionRect.top).toBe (0 + 'px')
        expect(regionRect.height).toBe 1 * lineHeightInPixels + 'px'
        expect(regionRect.left).toBe Math.round(2 * charWidth) + 'px'
        expect(regionRect.width).toBe Math.round(2 * charWidth) + 'px'

    it "renders highlights decoration's marker is added", ->
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 2

    it "removes highlights when a decoration is removed", ->
      decoration.destroy()
      waitsForNextDOMUpdate()

      runs ->
        regions = componentNode.querySelectorAll('.test-highlight .region')
        expect(regions.length).toBe 0

    it "does not render a highlight that is within a fold", ->
      editor.foldBufferRow(1)
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelectorAll('.test-highlight').length).toBe 0

    it "removes highlights when a decoration's marker is destroyed", ->
      marker.destroy()
      waitsForNextDOMUpdate()

      runs ->
        regions = componentNode.querySelectorAll('.test-highlight .region')
        expect(regions.length).toBe 0

    it "only renders highlights when a decoration's marker is valid", ->
      editor.getBuffer().insert([3, 2], 'n')
      waitsForNextDOMUpdate()

      runs ->
        expect(marker.isValid()).toBe false
        regions = componentNode.querySelectorAll('.test-highlight .region')
        expect(regions.length).toBe 0

        editor.getBuffer().undo()
        waitsForNextDOMUpdate()

      runs ->
        expect(marker.isValid()).toBe true
        regions = componentNode.querySelectorAll('.test-highlight .region')
        expect(regions.length).toBe 2

    it "allows multiple space-delimited decoration classes", ->
      decoration.setProperties(type: 'highlight', class: 'foo bar')
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelectorAll('.foo.bar').length).toBe 2
        decoration.setProperties(type: 'highlight', class: 'bar baz')
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelectorAll('.bar.baz').length).toBe 2

    it "renders classes on the regions directly if 'deprecatedRegionClass' option is defined", ->
      decoration = editor.decorateMarker(marker, type: 'highlight', class: 'test-highlight', deprecatedRegionClass: 'test-highlight-region')
      waitsForNextDOMUpdate()

      runs ->
        regions = componentNode.querySelectorAll('.test-highlight .region.test-highlight-region')
        expect(regions.length).toBe 2

    describe "when flashing a decoration via Decoration::flash()", ->
      highlightNode = null
      beforeEach ->
        highlightNode = componentNode.querySelectorAll('.test-highlight')[1]

      it "adds and removes the flash class specified in ::flash", ->
        expect(highlightNode.classList.contains('flash-class')).toBe false

        decoration.flash('flash-class', 10)
        waitsForNextDOMUpdate()

        runs ->
          expect(highlightNode.classList.contains('flash-class')).toBe true

        waitsFor -> not highlightNode.classList.contains('flash-class')

      describe "when ::flash is called again before the first has finished", ->
        it "removes the class from the decoration highlight before adding it for the second ::flash call", ->
          decoration.flash('flash-class', 30)
          waitsForNextDOMUpdate()
          runs -> expect(highlightNode.classList.contains('flash-class')).toBe true
          waits 2
          runs ->
            decoration.flash('flash-class', 10)
            waitsForNextDOMUpdate()
          runs -> expect(highlightNode.classList.contains('flash-class')).toBe false
          waitsFor -> highlightNode.classList.contains('flash-class')

    describe "when a decoration's marker moves", ->
      it "moves rendered highlights when the buffer is changed", ->
        regionStyle = componentNode.querySelector('.test-highlight .region').style
        originalTop = parseInt(regionStyle.top)

        expect(originalTop).toBe(2 * lineHeightInPixels)

        editor.getBuffer().insert([0, 0], '\n')
        waitsForNextDOMUpdate()

        runs ->
          regionStyle = componentNode.querySelector('.test-highlight .region').style
          newTop = parseInt(regionStyle.top)

          expect(newTop).toBe(0)

      it "moves rendered highlights when the marker is manually moved", ->
        regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe 2 * lineHeightInPixels

        marker.setBufferRange([[5, 8], [5, 13]])
        waitsForNextDOMUpdate()

        runs ->
          regionStyle = componentNode.querySelector('.test-highlight .region').style
          expect(parseInt(regionStyle.top)).toBe 2 * lineHeightInPixels

    describe "when a decoration is updated via Decoration::update", ->
      it "renders the decoration's new params", ->
        expect(componentNode.querySelector('.test-highlight')).toBeTruthy()

        decoration.setProperties(type: 'highlight', class: 'new-test-highlight')
        waitsForNextDOMUpdate()

        runs ->
          expect(componentNode.querySelector('.test-highlight')).toBeFalsy()
          expect(componentNode.querySelector('.new-test-highlight')).toBeTruthy()

  describe "overlay decoration rendering", ->
    [item, gutterWidth] = []
    beforeEach ->
      item = document.createElement('div')
      item.classList.add 'overlay-test'
      item.style.background = 'red'
      gutterWidth = componentNode.querySelector('.gutter').offsetWidth

    describe "when the marker is empty", ->
      it "renders an overlay decoration when added and removes the overlay when the decoration is destroyed", ->
        marker = editor.displayBuffer.markBufferRange([[2, 13], [2, 13]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', item})
        waitsForNextDOMUpdate()

        runs ->
          overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
          expect(overlay).toBe item

          decoration.destroy()
          waitsForNextDOMUpdate()

        runs ->
          overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
          expect(overlay).toBe null

      it "renders the overlay element with the CSS class specified by the decoration", ->
        marker = editor.displayBuffer.markBufferRange([[2, 13], [2, 13]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', class: 'my-overlay', item})
        waitsForNextDOMUpdate()

        runs ->
          overlay = component.getTopmostDOMNode().querySelector('atom-overlay.my-overlay')
          expect(overlay).not.toBe null

          child = overlay.querySelector('.overlay-test')
          expect(child).toBe item

    describe "when the marker is not empty", ->
      it "renders at the head of the marker by default", ->
        marker = editor.displayBuffer.markBufferRange([[2, 5], [2, 10]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', item})
        waitsForNextDOMUpdate()

        runs ->
          position = wrapperNode.pixelPositionForBufferPosition([2, 10])

          overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
          expect(overlay.style.left).toBe Math.round(position.left + gutterWidth) + 'px'
          expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

    describe "positioning the overlay when near the edge of the editor", ->
      [itemWidth, itemHeight, windowWidth, windowHeight] = []
      beforeEach ->
        atom.storeWindowDimensions()

        itemWidth = Math.round(4 * editor.getDefaultCharWidth())
        itemHeight = 4 * editor.getLineHeightInPixels()

        windowWidth = Math.round(gutterWidth + 30 * editor.getDefaultCharWidth())
        windowHeight = 10 * editor.getLineHeightInPixels()

        item.style.width = itemWidth + 'px'
        item.style.height = itemHeight + 'px'

        wrapperNode.style.width = windowWidth + 'px'
        wrapperNode.style.height = windowHeight + 'px'

        atom.setWindowDimensions({width: windowWidth, height: windowHeight})

        component.measureDimensions()
        component.measureWindowSize()
        waitsForNextDOMUpdate()

      afterEach ->
        atom.restoreWindowDimensions()

      # This spec should actually run on Linux as well, see TextEditorComponent#measureWindowSize for further information.
      it "slides horizontally left when near the right edge on #win32 and #darwin", ->
        [overlay, position] = []

        marker = editor.displayBuffer.markBufferRange([[0, 26], [0, 26]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', item})
        waitsForNextDOMUpdate()

        runs ->
          position = wrapperNode.pixelPositionForBufferPosition([0, 26])

          overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
          expect(overlay.style.left).toBe Math.round(position.left + gutterWidth) + 'px'
          expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

          editor.insertText('a')
          waitsForNextDOMUpdate()

        runs ->
          expect(overlay.style.left).toBe windowWidth - itemWidth + 'px'
          expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

          editor.insertText('b')
          waitsForNextDOMUpdate()

        runs ->
          expect(overlay.style.left).toBe windowWidth - itemWidth + 'px'
          expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

  describe "hidden input field", ->
    it "renders the hidden input field at the position of the last cursor if the cursor is on screen and the editor is focused", ->
      editor.setVerticalScrollMargin(0)
      editor.setHorizontalScrollMargin(0)

      inputNode = componentNode.querySelector('.hidden-input')
      wrapperNode.style.height = 5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]
        wrapperNode.setScrollTop(3 * lineHeightInPixels)
        wrapperNode.setScrollLeft(3 * charWidth)
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe 0
        expect(inputNode.offsetLeft).toBe 0

        # In bounds, not focused
        editor.setCursorBufferPosition([5, 4], autoscroll: false)
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe 0
        expect(inputNode.offsetLeft).toBe 0

        # In bounds and focused
        wrapperNode.focus() # updates via state change
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe (5 * lineHeightInPixels) - wrapperNode.getScrollTop()
        expect(inputNode.offsetLeft).toBeCloseTo (4 * charWidth) - wrapperNode.getScrollLeft(), 0

        # In bounds, not focused
        inputNode.blur() # updates via state change
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe 0
        expect(inputNode.offsetLeft).toBe 0

        # Out of bounds, not focused
        editor.setCursorBufferPosition([1, 2], autoscroll: false)
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe 0
        expect(inputNode.offsetLeft).toBe 0

        # Out of bounds, focused
        inputNode.focus() # updates via state change
        waitsForNextDOMUpdate()

      runs ->
        expect(inputNode.offsetTop).toBe 0
        expect(inputNode.offsetLeft).toBe 0

  describe "mouse interactions on the lines", ->
    linesNode = null

    beforeEach ->
      linesNode = componentNode.querySelector('.lines')

    describe "when the mouse is single-clicked above the first line", ->
      it "moves the cursor to the start of file buffer position", ->
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 3])
        height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          coordinates = clientCoordinatesForScreenPosition([0, 2])
          coordinates.clientY = -1
          linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
          waitsForNextDOMUpdate()

        runs ->
          expect(editor.getCursorScreenPosition()).toEqual [0, 0]

    describe "when the mouse is single-clicked below the last line", ->
      it "moves the cursor to the end of file buffer position", ->
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 0])
        height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          coordinates = clientCoordinatesForScreenPosition([0, 2])
          coordinates.clientY = height * 2
          linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
          waitsForNextDOMUpdate()

        runs ->
          expect(editor.getCursorScreenPosition()).toEqual [0, 3]

    describe "when a non-folded line is single-clicked", ->
      describe "when no modifier keys are held down", ->
        it "moves the cursor to the nearest screen position", ->
          wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
          wrapperNode.style.width = 10 * charWidth + 'px'
          component.measureDimensions()
          wrapperNode.setScrollTop(3.5 * lineHeightInPixels)
          wrapperNode.setScrollLeft(2 * charWidth)
          waitsForNextDOMUpdate()

          runs ->
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8])))
            waitsForNextDOMUpdate()

          runs ->
            expect(editor.getCursorScreenPosition()).toEqual [4, 8]

      describe "when the shift key is held down", ->
        it "selects to the nearest screen position", ->
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), shiftKey: true))
          waitsForNextDOMUpdate()

          runs ->
            expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [5, 6]]

      describe "when the command key is held down", ->
        describe "the current cursor position and screen position do not match", ->
          it "adds a cursor at the nearest screen position", ->
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), metaKey: true))
            waitsForNextDOMUpdate()

            runs ->
              expect(editor.getSelectedScreenRanges()).toEqual [[[3, 4], [3, 4]], [[5, 6], [5, 6]]]

        describe "when there are multiple cursors, and one of the cursor's screen position is the same as the mouse click screen position", ->
          it "removes a cursor at the mouse screen position", ->
            editor.setCursorScreenPosition([3, 4])
            editor.addCursorAtScreenPosition([5, 2])
            editor.addCursorAtScreenPosition([7, 5])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), metaKey: true))
            waitsForNextDOMUpdate()

            runs ->
              expect(editor.getSelectedScreenRanges()).toEqual [[[5, 2], [5, 2]], [[7, 5], [7, 5]]]

        describe "when there is a single cursor and the click occurs at the cursor's screen position", ->
          it "neither adds a new cursor nor removes the current cursor", ->
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), metaKey: true))
            waitsForNextDOMUpdate()

            runs ->
              expect(editor.getSelectedScreenRanges()).toEqual [[[3, 4], [3, 4]]]

    describe "when a non-folded line is double-clicked", ->
      describe "when no modifier keys are held down", ->
        it "selects the word containing the nearest screen position", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [5, 13]]

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[6, 6], [6, 6]]

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), detail: 1, shiftKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[6, 6], [8, 8]]

      describe "when the command key is held down", ->
        it "selects the word containing the newly-added cursor", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))

          expect(editor.getSelectedScreenRanges()).toEqual [[[0, 0], [0, 0]], [[5, 6], [5, 13]]]

    describe "when a non-folded line is triple-clicked", ->
      describe "when no modifier keys are held down", ->
        it "selects the line containing the nearest screen position", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 3))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[5, 0], [6, 0]]

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), detail: 1, shiftKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[5, 0], [7, 0]]

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([7, 5]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), detail: 1, shiftKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual [[7, 5], [8, 8]]

      describe "when the command key is held down", ->
        it "selects the line containing the newly-added cursor", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 3, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRanges()).toEqual [[[0, 0], [0, 0]], [[5, 0], [6, 0]]]

    describe "when the mouse is clicked and dragged", ->
      it "selects to the nearest screen position until the mouse button is released", ->
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))

        waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [10, 0]]

          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([12, 0]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [10, 0]]

      it "autoscrolls when the cursor approaches the boundaries of the editor", ->
        wrapperNode.style.height = '100px'
        wrapperNode.style.width = '100px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe(0)
          expect(wrapperNode.getScrollLeft()).toBe(0)

          linesNode.dispatchEvent(buildMouseEvent('mousedown', {clientX: 0, clientY: 0}, which: 1))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', {clientX: 100, clientY: 50}, which: 1))
          waitsForAnimationFrame() for i in [0..5]

        runs ->
          expect(wrapperNode.getScrollTop()).toBe(0)
          expect(wrapperNode.getScrollLeft()).toBeGreaterThan(0)

          linesNode.dispatchEvent(buildMouseEvent('mousemove', {clientX: 100, clientY: 100}, which: 1))
          waitsForAnimationFrame() for i in [0..5]

        [previousScrollTop, previousScrollLeft] = []

        runs ->
          expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)

          previousScrollTop = wrapperNode.getScrollTop()
          previousScrollLeft = wrapperNode.getScrollLeft()

          linesNode.dispatchEvent(buildMouseEvent('mousemove', {clientX: 10, clientY: 50}, which: 1))
          waitsForAnimationFrame() for i in [0..5]

        runs ->
          expect(wrapperNode.getScrollTop()).toBe(previousScrollTop)
          expect(wrapperNode.getScrollLeft()).toBeLessThan(previousScrollLeft)

          linesNode.dispatchEvent(buildMouseEvent('mousemove', {clientX: 10, clientY: 10}, which: 1))
          waitsForAnimationFrame() for i in [0..5]

        runs ->
          expect(wrapperNode.getScrollTop()).toBeLessThan(previousScrollTop)

      it "stops selecting if the mouse is dragged into the dev tools", ->
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
        waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), which: 0))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

      it "stops selecting before the buffer is modified during the drag", ->
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
        waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

          editor.insertText('x')
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 5], [2, 5]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), which: 1))
          expect(editor.getSelectedScreenRange()).toEqual [[2, 5], [2, 5]]

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([5, 4]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [5, 4]]

          editor.delete()
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [2, 4]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), which: 1))
          expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [2, 4]]

      describe "when the command key is held down", ->
        it "adds a new selection and selects to the nearest screen position, then merges intersecting selections when the mouse button is released", ->
          editor.setSelectedScreenRange([[4, 4], [4, 9]])

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1, metaKey: true))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
          waitsForAnimationFrame()

          runs ->
            expect(editor.getSelectedScreenRanges()).toEqual [[[4, 4], [4, 9]], [[2, 4], [6, 8]]]

            linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([4, 6]), which: 1))
            waitsForAnimationFrame()

          runs ->
            expect(editor.getSelectedScreenRanges()).toEqual [[[4, 4], [4, 9]], [[2, 4], [4, 6]]]

            linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([4, 6]), which: 1))
            expect(editor.getSelectedScreenRanges()).toEqual [[[2, 4], [4, 9]]]

      describe "when the editor is destroyed while dragging", ->
        it "cleans up the handlers for window.mouseup and window.mousemove", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
          waitsForAnimationFrame()

          runs ->
            spyOn(window, 'removeEventListener').andCallThrough()

            linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 10]), which: 1))
            editor.destroy()
            waitsForAnimationFrame()

          runs ->
            call.args.pop() for call in window.removeEventListener.calls
            expect(window.removeEventListener).toHaveBeenCalledWith('mouseup')
            expect(window.removeEventListener).toHaveBeenCalledWith('mousemove')

    describe "when the mouse is double-clicked and dragged", ->
      it "expands the selection over the nearest word as the cursor moves", ->
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height =  6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2))
          expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [5, 13]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), which: 1))
          waitsForAnimationFrame()

        maximalScrollTop = null
        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [12, 2]]

          maximalScrollTop = wrapperNode.getScrollTop()

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([9, 3]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [9, 4]]
          expect(wrapperNode.getScrollTop()).toBe maximalScrollTop # does not autoscroll upward (regression)

          linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), which: 1))

    describe "when the mouse is triple-clicked and dragged", ->
      it "expands the selection over the nearest line as the cursor moves", ->
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height =  6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 1))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 3))
          expect(editor.getSelectedScreenRange()).toEqual [[5, 0], [6, 0]]

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), which: 1))
          waitsForAnimationFrame()

        maximalScrollTop = null
        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[5, 0], [12, 2]]

          maximalScrollTop = wrapperNode.getScrollTop()

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 4]), which: 1))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[5, 0], [8, 0]]
          expect(wrapperNode.getScrollTop()).toBe maximalScrollTop # does not autoscroll upward (regression)

          linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), which: 1))

    describe "when a line is folded", ->
      beforeEach ->
        editor.foldBufferRow 4
        waitsForNextDOMUpdate()

      describe "when the folded line's fold-marker is clicked", ->
        it "unfolds the buffer row", ->
          target = component.lineNodeForScreenRow(4).querySelector '.fold-marker'
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8]), {target}))
          expect(editor.isFoldedAtBufferRow 4).toBe false

    describe "when the horizontal scrollbar is interacted with", ->
      it "clicking on the scrollbar does not move the cursor", ->
        target = horizontalScrollbarNode
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8]), {target}))
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]

  describe "mouse interactions on the gutter", ->
    gutterNode = null

    beforeEach ->
      gutterNode = componentNode.querySelector('.gutter')

    describe "when the component is destroyed", ->
      it "stops listening for selection events", ->
        component.destroy()

        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))

        expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [0, 0]]

    describe "when the gutter is clicked", ->
      it "selects the clicked row", ->
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        expect(editor.getSelectedScreenRange()).toEqual [[4, 0], [5, 0]]

    describe "when the gutter is meta-clicked", ->
      it "creates a new selection for the clicked row", ->
        editor.setSelectedScreenRange([[3, 0], [3, 2]])

        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
        expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [5, 0]]]

        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
        expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [5, 0]], [[6, 0], [7, 0]]]

    describe "when the gutter is shift-clicked", ->
      beforeEach ->
        editor.setSelectedScreenRange([[3, 4], [4, 5]])

      describe "when the clicked row is before the current selection's tail", ->
        it "selects to the beginning of the clicked row", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))
          expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [3, 4]]

      describe "when the clicked row is after the current selection's tail", ->
        it "selects to the beginning of the row following the clicked row", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), shiftKey: true))
          expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [7, 0]]

    describe "when the gutter is clicked and dragged", ->
      describe "when dragging downward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
          waitsForAnimationFrame()

          runs ->
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
            expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 0]]

      describe "when dragging upward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
          waitsForAnimationFrame()

          runs ->
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2)))
            expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 0]]

      it "orients the selection appropriately when the mouse moves above or below the initially-clicked row", ->
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
        waitsForAnimationFrame()

        runs ->
          expect(editor.getLastSelection().isReversed()).toBe true
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
          waitsForAnimationFrame()

        runs ->
          expect(editor.getLastSelection().isReversed()).toBe false

      it "autoscrolls when the cursor approaches the top or bottom of the editor", ->
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0

          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
          waitsForAnimationFrame()

        maxScrollTop = null
        runs ->
          expect(wrapperNode.getScrollTop()).toBeGreaterThan 0
          maxScrollTop = wrapperNode.getScrollTop()

          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(10)))
          waitsForAnimationFrame()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe maxScrollTop

          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
          waitsForAnimationFrame()

        runs ->
          expect(wrapperNode.getScrollTop()).toBeLessThan maxScrollTop

      it "stops selecting if a textInput event occurs during the drag", ->
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
        waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 0]]

          inputEvent = new Event('textInput')
          inputEvent.data = 'x'
          Object.defineProperty(inputEvent, 'target', get: -> componentNode.querySelector('.hidden-input'))
          componentNode.dispatchEvent(inputEvent)
          waitsForAnimationFrame()

        runs ->
          expect(editor.getSelectedScreenRange()).toEqual [[2, 1], [2, 1]]

          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(12)))
          expect(editor.getSelectedScreenRange()).toEqual [[2, 1], [2, 1]]

    describe "when the gutter is meta-clicked and dragged", ->
      beforeEach ->
        editor.setSelectedScreenRange([[3, 0], [3, 2]])

      describe "when dragging downward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          waitsForAnimationFrame()

          runs ->
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [7, 0]]]

        it "merges overlapping selections when the mouse button is released", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          waitsForAnimationFrame()

          runs ->
            expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[2, 0], [7, 0]]]

            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[2, 0], [7, 0]]]

      describe "when dragging upward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
          waitsForAnimationFrame()

          runs ->
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [7, 0]]]

        it "merges overlapping selections", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          waitsForAnimationFrame()

          runs ->
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[2, 0], [7, 0]]]

    describe "when the gutter is shift-clicked and dragged", ->
      describe "when the shift-click is below the existing selection's tail", ->
        describe "when dragging downward", ->
          it "selects the rows between the existing selection's tail and the end of the drag", ->
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [9, 0]]

        describe "when dragging upward", ->
          it "selects the rows between the end of the drag and the tail of the existing selection", ->
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5)))
            waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[4, 4], [6, 0]]

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
              waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [4, 4]]

      describe "when the shift-click is above the existing selection's tail", ->
        describe "when dragging upward", ->
          it "selects the rows between the end of the drag and the tail of the existing selection", ->
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [4, 4]]

        describe "when dragging downward", ->
          it "selects the rows between the existing selection's tail and the end of the drag", ->
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
            waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [3, 4]]

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
              waitsForAnimationFrame()

            runs ->
              expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [9, 0]]

    describe "when soft wrap is enabled", ->
      beforeEach ->
        gutterNode = componentNode.querySelector('.gutter')
        editor.setSoftWrapped(true)
        waitsForNextDOMUpdate()
        runs ->
          componentNode.style.width = 21 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
          component.measureDimensions()
          waitsForNextDOMUpdate()

      describe "when the gutter is clicked", ->
        it "selects the clicked buffer row", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
          expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [2, 0]]

      describe "when the gutter is meta-clicked", ->
        it "creates a new selection for the clicked buffer row", ->
          editor.setSelectedScreenRange([[1, 0], [1, 2]])

          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[1, 0], [1, 2]], [[2, 0], [5, 0]]]

          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[1, 0], [1, 2]], [[2, 0], [5, 0]], [[5, 0], [10, 0]]]

      describe "when the gutter is shift-clicked", ->
        beforeEach ->
          editor.setSelectedScreenRange([[7, 4], [7, 6]])

        describe "when the clicked row is before the current selection's tail", ->
          it "selects to the beginning of the clicked buffer row", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))
            expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [7, 4]]

        describe "when the clicked row is after the current selection's tail", ->
          it "selects to the beginning of the screen row following the clicked buffer row", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), shiftKey: true))
            expect(editor.getSelectedScreenRange()).toEqual [[7, 4], [16, 0]]

      describe "when the gutter is clicked and dragged", ->
        describe "when dragging downward", ->
          it "selects the buffer row containing the click, then screen rows until the end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
              expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [6, 14]]

        describe "when dragging upward", ->
          it "selects the buffer row containing the click, then screen rows until the end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(1)))
              expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [10, 0]]

      describe "when the gutter is meta-clicked and dragged", ->
        beforeEach ->
          editor.setSelectedScreenRange([[7, 4], [7, 6]])

        describe "when dragging downward", ->
          it "adds a selection from the buffer row containing the click to the screen row containing the end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3), metaKey: true))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(3), metaKey: true))
              expect(editor.getSelectedScreenRanges()).toEqual [[[7, 4], [7, 6]], [[0, 0], [3, 14]]]

          it "merges overlapping selections on mouseup", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7), metaKey: true))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(7), metaKey: true))
              expect(editor.getSelectedScreenRanges()).toEqual [[[0, 0], [7, 12]]]

        describe "when dragging upward", ->
          it "adds a selection from the buffer row containing the click to the screen row containing the end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11), metaKey: true))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(11), metaKey: true))
              expect(editor.getSelectedScreenRanges()).toEqual [[[7, 4], [7, 6]], [[11, 4], [19, 0]]]

          it "merges overlapping selections on mouseup", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5), metaKey: true))
            waitsForAnimationFrame()
            runs ->
              gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(5), metaKey: true))
              expect(editor.getSelectedScreenRanges()).toEqual [[[5, 0], [19, 0]]]

      describe "when the gutter is shift-clicked and dragged", ->
        describe "when the shift-click is below the existing selection's tail", ->
          describe "when dragging downward", ->
            it "selects the screen rows between the existing selection's tail and the end of the drag", ->
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11)))
              waitsForAnimationFrame()
              runs ->
                expect(editor.getSelectedScreenRange()).toEqual [[1, 4], [11, 14]]

          describe "when dragging upward", ->
            it "selects the screen rows between the end of the drag and the tail of the existing selection", ->
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
              waitsForAnimationFrame()
              runs ->
                expect(editor.getSelectedScreenRange()).toEqual [[1, 4], [7, 12]]

        describe "when the shift-click is above the existing selection's tail", ->
          describe "when dragging upward", ->
            it "selects the screen rows between the end of the drag and the tail of the existing selection", ->
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(3), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
              waitsForAnimationFrame()
              runs ->
                expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [7, 4]]

          describe "when dragging downward", ->
            it "selects the screen rows between the existing selection's tail and the end of the drag", ->
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3)))
              waitsForAnimationFrame()
              runs ->
                expect(editor.getSelectedScreenRange()).toEqual [[3, 2], [7, 4]]

  describe "focus handling", ->
    inputNode = null

    beforeEach ->
      inputNode = componentNode.querySelector('.hidden-input')

    it "transfers focus to the hidden input", ->
      expect(document.activeElement).toBe document.body
      wrapperNode.focus()
      expect(document.activeElement).toBe wrapperNode
      expect(wrapperNode.shadowRoot.activeElement).toBe inputNode

    it "adds the 'is-focused' class to the editor when the hidden input is focused", ->
      expect(document.activeElement).toBe document.body
      inputNode.focus()
      waitsForNextDOMUpdate()
      runs ->
        expect(componentNode.classList.contains('is-focused')).toBe true
        expect(wrapperNode.classList.contains('is-focused')).toBe true
        inputNode.blur()
        waitsForNextDOMUpdate()
      runs ->
        expect(componentNode.classList.contains('is-focused')).toBe false
        expect(wrapperNode.classList.contains('is-focused')).toBe false

  describe "selection handling", ->
    cursor = null

    beforeEach ->
      console.log editor.getText()
      editor.setCursorScreenPosition([0, 0])
      waitsForNextDOMUpdate()

    it "adds the 'has-selection' class to the editor when there is a selection", ->
      expect(componentNode.classList.contains('has-selection')).toBe false
      editor.selectDown()
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.classList.contains('has-selection')).toBe true
        editor.moveDown()
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.classList.contains('has-selection')).toBe false

  describe "scrolling", ->
    it "updates the vertical scrollbar when the scrollTop is changed in the model", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.scrollTop).toBe 0
        wrapperNode.setScrollTop(10)
        waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.scrollTop).toBe 10

    it "updates the horizontal scrollbar and the x transform of the lines based on the scrollLeft of the model", ->
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      tilesNodes = null
      runs ->
        tilesNodes = component.tileNodesForLines()

        top = 0
        for tileNode in tilesNodes
          expect(tileNode.style['-webkit-transform']).toBe "translate3d(0px, #{top}px, 0px)"
          top += tileNode.offsetHeight

        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        wrapperNode.setScrollLeft(100)
        waitsForNextDOMUpdate()

      runs ->
        top = 0
        for tileNode in tilesNodes
          expect(tileNode.style['-webkit-transform']).toBe "translate3d(-100px, #{top}px, 0px)"
          top += tileNode.offsetHeight

        expect(horizontalScrollbarNode.scrollLeft).toBe 100

    it "updates the scrollLeft of the model when the scrollLeft of the horizontal scrollbar changes", ->
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(wrapperNode.getScrollLeft()).toBe 0
        horizontalScrollbarNode.scrollLeft = 100
        horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
        waitsForNextDOMUpdate()

      runs ->
        expect(wrapperNode.getScrollLeft()).toBe 100

    it "does not obscure the last line with the horizontal scrollbar", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
      waitsForNextDOMUpdate()

      lastLineNode = null
      runs ->
        lastLineNode = component.lineNodeForScreenRow(editor.getLastScreenRow())
        bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
        topOfHorizontalScrollbar = horizontalScrollbarNode.getBoundingClientRect().top
        expect(bottomOfLastLine).toBe topOfHorizontalScrollbar

        # Scroll so there's no space below the last line when the horizontal scrollbar disappears
        wrapperNode.style.width = 100 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
        bottomOfEditor = componentNode.getBoundingClientRect().bottom
        expect(bottomOfLastLine).toBe bottomOfEditor

    it "does not obscure the last character of the longest line with the vertical scrollbar", ->
      wrapperNode.style.height = 7 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      wrapperNode.setScrollLeft(Infinity)
      waitsForNextDOMUpdate()

      runs ->
        rightOfLongestLine = component.lineNodeForScreenRow(6).querySelector('.line > span:last-child').getBoundingClientRect().right
        leftOfVerticalScrollbar = verticalScrollbarNode.getBoundingClientRect().left
        expect(Math.round(rightOfLongestLine)).toBeCloseTo leftOfVerticalScrollbar - 1, 0 # Leave 1 px so the cursor is visible on the end of the line

    it "only displays dummy scrollbars when scrollable in that direction", ->
      expect(verticalScrollbarNode.style.display).toBe 'none'
      expect(horizontalScrollbarNode.style.display).toBe 'none'

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.display).toBe ''
        expect(horizontalScrollbarNode.style.display).toBe 'none'

        componentNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.display).toBe ''
        expect(horizontalScrollbarNode.style.display).toBe ''

        wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.display).toBe 'none'
        expect(horizontalScrollbarNode.style.display).toBe ''

    it "makes the dummy scrollbar divs only as tall/wide as the actual scrollbars", ->
      wrapperNode.style.height = 4 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()


      runs ->
        atom.styles.addStyleSheet """
          ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
          }
        """, context: 'atom-text-editor'

      waitsForAnimationFrame() # handle stylesheet change event
      waitsForAnimationFrame() # perform requested update

      runs ->
        scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')
        expect(verticalScrollbarNode.offsetWidth).toBe 8
        expect(horizontalScrollbarNode.offsetHeight).toBe 8
        expect(scrollbarCornerNode.offsetWidth).toBe 8
        expect(scrollbarCornerNode.offsetHeight).toBe 8

        atom.themes.removeStylesheet('test')

    it "assigns the bottom/right of the scrollbars to the width of the opposite scrollbar if it is visible", ->
      scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')

      expect(verticalScrollbarNode.style.bottom).toBe '0px'
      expect(horizontalScrollbarNode.style.right).toBe '0px'

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.bottom).toBe '0px'
        expect(horizontalScrollbarNode.style.right).toBe verticalScrollbarNode.offsetWidth + 'px'
        expect(scrollbarCornerNode.style.display).toBe 'none'

        componentNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.bottom).toBe horizontalScrollbarNode.offsetHeight + 'px'
        expect(horizontalScrollbarNode.style.right).toBe verticalScrollbarNode.offsetWidth + 'px'
        expect(scrollbarCornerNode.style.display).toBe ''

        wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        expect(verticalScrollbarNode.style.bottom).toBe horizontalScrollbarNode.offsetHeight + 'px'
        expect(horizontalScrollbarNode.style.right).toBe '0px'
        expect(scrollbarCornerNode.style.display).toBe 'none'

    it "accounts for the width of the gutter in the scrollWidth of the horizontal scrollbar", ->
      gutterNode = componentNode.querySelector('.gutter')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        expect(horizontalScrollbarNode.scrollWidth).toBe wrapperNode.getScrollWidth()
        expect(horizontalScrollbarNode.style.left).toBe '0px'

  describe "mousewheel events", ->
    beforeEach ->
      atom.config.set('editor.scrollSensitivity', 100)

    describe "updating scrollTop and scrollLeft", ->
      beforeEach ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

      it "updates the scrollLeft or scrollTop on mousewheel events depending on which delta is greater (x or y)", ->
        expect(verticalScrollbarNode.scrollTop).toBe 0
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -5, wheelDeltaY: -10))

        waitsForAnimationFrame()

        runs ->
          expect(verticalScrollbarNode.scrollTop).toBe 10
          expect(horizontalScrollbarNode.scrollLeft).toBe 0

          componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -15, wheelDeltaY: -5))
          waitsForAnimationFrame()

        runs ->
          expect(verticalScrollbarNode.scrollTop).toBe 10
          expect(horizontalScrollbarNode.scrollLeft).toBe 15

      it "updates the scrollLeft or scrollTop according to the scroll sensitivity", ->
        atom.config.set('editor.scrollSensitivity', 50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -5, wheelDeltaY: -10))
        waitsForAnimationFrame()

        runs ->
          expect(horizontalScrollbarNode.scrollLeft).toBe 0

          componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -15, wheelDeltaY: -5))
          waitsForAnimationFrame()

        runs ->
          expect(verticalScrollbarNode.scrollTop).toBe 5
          expect(horizontalScrollbarNode.scrollLeft).toBe 7

      it "uses the previous scrollSensitivity when the value is not an int", ->
        atom.config.set('editor.scrollSensitivity', 'nope')
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -10))
        waitsForAnimationFrame()

        runs ->
          expect(verticalScrollbarNode.scrollTop).toBe 10

      it "parses negative scrollSensitivity values at the minimum", ->
        atom.config.set('editor.scrollSensitivity', -50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -10))
        waitsForAnimationFrame()

        runs ->
          expect(verticalScrollbarNode.scrollTop).toBe 1

    describe "when the mousewheel event's target is a line", ->
      it "keeps the line on the DOM if it is scrolled off-screen", ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        lineNode = null
        runs ->
          lineNode = componentNode.querySelector('.line')
          wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -500)
          Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
          componentNode.dispatchEvent(wheelEvent)
          waitsForAnimationFrame()

        runs ->
          expect(componentNode.contains(lineNode)).toBe true

      it "does not set the mouseWheelScreenRow if scrolling horizontally", ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        lineNode = null
        runs ->
          lineNode = componentNode.querySelector('.line')
          wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 10, wheelDeltaY: 0)
          Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
          componentNode.dispatchEvent(wheelEvent)
          waitsForAnimationFrame()

        runs ->
          expect(component.presenter.mouseWheelScreenRow).toBe null

      it "clears the mouseWheelScreenRow after a delay even if the event does not cause scrolling", ->
        expect(wrapperNode.getScrollTop()).toBe 0

        lineNode = componentNode.querySelector('.line')
        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: 10)
        Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
        componentNode.dispatchEvent(wheelEvent)

        expect(wrapperNode.getScrollTop()).toBe 0

        expect(component.presenter.mouseWheelScreenRow).toBe 0

        waitsFor -> not component.presenter.mouseWheelScreenRow?

      it "does not preserve the line if it is on screen", ->
        expect(componentNode.querySelectorAll('.line-number').length).toBe 14 # dummy line
        lineNodes = componentNode.querySelectorAll('.line')
        expect(lineNodes.length).toBe 13
        lineNode = lineNodes[0]

        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: 100) # goes nowhere, we're already at scrollTop 0
        Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
        componentNode.dispatchEvent(wheelEvent)

        expect(component.presenter.mouseWheelScreenRow).toBe 0
        editor.insertText("hello")
        expect(componentNode.querySelectorAll('.line-number').length).toBe 14 # dummy line
        expect(componentNode.querySelectorAll('.line').length).toBe 13

    describe "when the mousewheel event's target is a line number", ->
      it "keeps the line number on the DOM if it is scrolled off-screen", ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        lineNumberNode = null
        runs ->
          lineNumberNode = componentNode.querySelectorAll('.line-number')[1]
          wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -500)
          Object.defineProperty(wheelEvent, 'target', get: -> lineNumberNode)
          componentNode.dispatchEvent(wheelEvent)
          waitsForAnimationFrame()

        runs ->
          expect(componentNode.contains(lineNumberNode)).toBe true

    it "only prevents the default action of the mousewheel event if it actually lead to scrolling", ->
      spyOn(WheelEvent::, 'preventDefault').andCallThrough()

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * charWidth + 'px'
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        # try to scroll past the top, which is impossible
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: 50))
        expect(wrapperNode.getScrollTop()).toBe 0
        expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

        # scroll to the bottom in one huge event
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -3000))
        waitsForAnimationFrame()

      runs ->
        maxScrollTop = wrapperNode.getScrollTop()
        expect(WheelEvent::preventDefault).toHaveBeenCalled()
        WheelEvent::preventDefault.reset()

        # try to scroll past the bottom, which is impossible
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -30))
        expect(wrapperNode.getScrollTop()).toBe maxScrollTop
        expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

        # try to scroll past the left side, which is impossible
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 50, wheelDeltaY: 0))
        expect(wrapperNode.getScrollLeft()).toBe 0
        expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

        # scroll all the way right
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -3000, wheelDeltaY: 0))
        waitsForAnimationFrame()

      runs ->
        maxScrollLeft = wrapperNode.getScrollLeft()
        expect(WheelEvent::preventDefault).toHaveBeenCalled()
        WheelEvent::preventDefault.reset()

        # try to scroll past the right side, which is impossible
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -30, wheelDeltaY: 0))
        expect(wrapperNode.getScrollLeft()).toBe maxScrollLeft
        expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

  describe "input events", ->
    inputNode = null

    beforeEach ->
      inputNode = componentNode.querySelector('.hidden-input')

    buildTextInputEvent = ({data, target}) ->
      event = new Event('textInput')
      event.data = data
      Object.defineProperty(event, 'target', get: -> target)
      event

    it "inserts the newest character in the input's value into the buffer", ->
      componentNode.dispatchEvent(buildTextInputEvent(data: 'x', target: inputNode))
      waitsForNextDOMUpdate()
      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe 'xvar quicksort = function () {'
        componentNode.dispatchEvent(buildTextInputEvent(data: 'y', target: inputNode))
        waitsForNextDOMUpdate()
      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe 'xyvar quicksort = function () {'

    it "replaces the last character if the length of the input's value doesn't increase, as occurs with the accented character menu", ->
      componentNode.dispatchEvent(buildTextInputEvent(data: 'u', target: inputNode))
      waitsForNextDOMUpdate()
      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe 'uvar quicksort = function () {'

        # simulate the accented character suggestion's selection of the previous character
        inputNode.setSelectionRange(0, 1)
        componentNode.dispatchEvent(buildTextInputEvent(data: 'ü', target: inputNode))
        waitsForNextDOMUpdate()

      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe 'üvar quicksort = function () {'

    it "does not handle input events when input is disabled", ->
      component.setInputEnabled(false)
      componentNode.dispatchEvent(buildTextInputEvent(data: 'x', target: inputNode))
      expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () {'
      waitsForAnimationFrame()
      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () {'

    it "groups events that occur close together in time into single undo entries", ->
      currentTime = 0
      spyOn(Date, 'now').andCallFake -> currentTime

      atom.config.set('editor.undoGroupingInterval', 100)

      editor.setText("")
      componentNode.dispatchEvent(buildTextInputEvent(data: 'x', target: inputNode))

      currentTime += 99
      componentNode.dispatchEvent(buildTextInputEvent(data: 'y', target: inputNode))

      currentTime += 99
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', bubbles: true, cancelable: true))

      currentTime += 101
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', bubbles: true, cancelable: true))
      expect(editor.getText()).toBe "xy\nxy\nxy"

      componentNode.dispatchEvent(new CustomEvent('core:undo', bubbles: true, cancelable: true))
      expect(editor.getText()).toBe "xy\nxy"

      componentNode.dispatchEvent(new CustomEvent('core:undo', bubbles: true, cancelable: true))
      expect(editor.getText()).toBe ""

    describe "when IME composition is used to insert international characters", ->
      inputNode = null

      buildIMECompositionEvent = (event, {data, target}={}) ->
        event = new Event(event)
        event.data = data
        Object.defineProperty(event, 'target', get: -> target)
        event

      beforeEach ->
        inputNode = inputNode = componentNode.querySelector('.hidden-input')

      describe "when nothing is selected", ->
        it "inserts the chosen completion", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'svar quicksort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'sdvar quicksort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          componentNode.dispatchEvent(buildTextInputEvent(data: '速度', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe '速度var quicksort = function () {'

        it "reverts back to the original text when the completion helper is dismissed", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'svar quicksort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'sdvar quicksort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () {'

        it "allows multiple accented character to be inserted with the ' on a US international layout", ->
          inputNode.value = "'"
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: "'", target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe "'var quicksort = function () {"

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          componentNode.dispatchEvent(buildTextInputEvent(data: 'á', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe "ávar quicksort = function () {"

          inputNode.value = "'"
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: "'", target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe "á'var quicksort = function () {"

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          componentNode.dispatchEvent(buildTextInputEvent(data: 'á', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe "áávar quicksort = function () {"

      describe "when a string is selected", ->
        beforeEach ->
          editor.setSelectedBufferRanges [[[0, 4], [0, 9]], [[0, 16], [0, 19]]] # select 'quick' and 'fun'

        it "inserts the chosen completion", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var ssort = sction () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var sdsort = sdction () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          componentNode.dispatchEvent(buildTextInputEvent(data: '速度', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var 速度sort = 速度ction () {'

        it "reverts back to the original text when the completion helper is dismissed", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var ssort = sction () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var sdsort = sdction () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () {'

  describe "commands", ->
    describe "editor:consolidate-selections", ->
      it "consolidates selections on the editor model, aborting the key binding if there is only one selection", ->
        spyOn(editor, 'consolidateSelections').andCallThrough()

        event = new CustomEvent('editor:consolidate-selections', bubbles: true, cancelable: true)
        event.abortKeyBinding = jasmine.createSpy("event.abortKeyBinding")
        componentNode.dispatchEvent(event)

        expect(editor.consolidateSelections).toHaveBeenCalled()
        expect(event.abortKeyBinding).toHaveBeenCalled()

  describe "when changing the font", ->
    it "measures the default char, the korean char, the double width char and the half width char widths", ->
      expect(editor.getDefaultCharWidth()).toBeCloseTo(12, 0)

      component.setFontSize(10)
      waitsForNextDOMUpdate()

      runs ->
        expect(editor.getDefaultCharWidth()).toBeCloseTo(6, 0)
        expect(editor.getKoreanCharWidth()).toBeCloseTo(9, 0)
        expect(editor.getDoubleWidthCharWidth()).toBe(10)
        expect(editor.getHalfWidthCharWidth()).toBe(5)

  describe "hiding and showing the editor", ->
    describe "when the editor is hidden when it is mounted", ->
      it "defers measurement and rendering until the editor becomes visible", ->
        wrapperNode.remove()

        hiddenParent = document.createElement('div')
        hiddenParent.style.display = 'none'
        contentNode.appendChild(hiddenParent)

        wrapperNode = new TextEditorElement()
        wrapperNode.tileSize = tileSize
        wrapperNode.initialize(editor, atom)
        hiddenParent.appendChild(wrapperNode)

        {component} = wrapperNode
        componentNode = component.getDomNode()
        expect(componentNode.querySelectorAll('.line').length).toBe 0

        hiddenParent.style.display = 'block'
        atom.views.performDocumentPoll()

        expect(componentNode.querySelectorAll('.line').length).toBeGreaterThan 0

    describe "when the lineHeight changes while the editor is hidden", ->
      it "does not attempt to measure the lineHeightInPixels until the editor becomes visible again", ->
        initialLineHeightInPixels = null
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        initialLineHeightInPixels = editor.getLineHeightInPixels()

        component.setLineHeight(2)
        expect(editor.getLineHeightInPixels()).toBe initialLineHeightInPixels

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        expect(editor.getLineHeightInPixels()).not.toBe initialLineHeightInPixels

    describe "when the fontSize changes while the editor is hidden", ->
      it "does not attempt to measure the lineHeightInPixels or defaultCharWidth until the editor becomes visible again", ->
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        initialLineHeightInPixels = editor.getLineHeightInPixels()
        initialCharWidth = editor.getDefaultCharWidth()

        component.setFontSize(22)
        expect(editor.getLineHeightInPixels()).toBe initialLineHeightInPixels
        expect(editor.getDefaultCharWidth()).toBe initialCharWidth

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        expect(editor.getLineHeightInPixels()).not.toBe initialLineHeightInPixels
        expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

      it "does not re-measure character widths until the editor is shown again", ->
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        component.setFontSize(22)
        editor.getBuffer().insert([0, 0], 'a') # regression test against atom/atom#3318

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        editor.setCursorBufferPosition([0, Infinity])
        waitsForNextDOMUpdate()

        runs ->
          cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
          line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
          expect(cursorLeft).toBeCloseTo line0Right, 0

    describe "when the fontFamily changes while the editor is hidden", ->
      it "does not attempt to measure the defaultCharWidth until the editor becomes visible again", ->
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        initialLineHeightInPixels = editor.getLineHeightInPixels()
        initialCharWidth = editor.getDefaultCharWidth()

        component.setFontFamily('serif')
        expect(editor.getDefaultCharWidth()).toBe initialCharWidth

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

      it "does not re-measure character widths until the editor is shown again", ->
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        component.setFontFamily('serif')

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        editor.setCursorBufferPosition([0, Infinity])
        waitsForNextDOMUpdate()

        runs ->
          cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
          line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
          expect(cursorLeft).toBeCloseTo line0Right, 0

    describe "when stylesheets change while the editor is hidden", ->
      afterEach ->
        atom.themes.removeStylesheet('test')

      it "does not re-measure character widths until the editor is shown again", ->
        atom.config.set('editor.fontFamily', 'sans-serif')

        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()

        atom.themes.applyStylesheet 'test', """
          .function.js {
            font-weight: bold;
          }
        """

        wrapperNode.style.display = ''
        component.checkForVisibilityChange()

        editor.setCursorBufferPosition([0, Infinity])
        waitsForNextDOMUpdate()

        runs ->
          cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
          line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
          expect(cursorLeft).toBeCloseTo line0Right, 0

  describe "soft wrapping", ->
    beforeEach ->
      editor.setSoftWrapped(true)
      waitsForNextDOMUpdate()

    it "updates the wrap location when the editor is resized", ->
      newHeight = 4 * editor.getLineHeightInPixels() + "px"
      expect(parseInt(newHeight)).toBeLessThan wrapperNode.offsetHeight
      wrapperNode.style.height = newHeight
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelectorAll('.line')).toHaveLength(7) # visible rows + model longest screen row

        gutterWidth = componentNode.querySelector('.gutter').offsetWidth
        componentNode.style.width = gutterWidth + 14 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
        atom.views.performDocumentPoll()
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.line').textContent).toBe "var quicksort "

    it "accounts for the scroll view's padding when determining the wrap location", ->
      scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewNode.style.paddingLeft = 20 + 'px'
      componentNode.style.width = 30 * charWidth + 'px'

      atom.views.performDocumentPoll()
      waitsForNextDOMUpdate()

      runs ->
        expect(component.lineNodeForScreenRow(0).textContent).toBe "var quicksort = "

  describe "default decorations", ->
    it "applies .cursor-line decorations for line numbers overlapping selections", ->
      editor.setCursorScreenPosition([4, 4])
      waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(3, 'cursor-line')).toBe false
        expect(lineNumberHasClass(4, 'cursor-line')).toBe true
        expect(lineNumberHasClass(5, 'cursor-line')).toBe false

        editor.setSelectedScreenRange([[3, 4], [4, 4]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(3, 'cursor-line')).toBe true
        expect(lineNumberHasClass(4, 'cursor-line')).toBe true

        editor.setSelectedScreenRange([[3, 4], [4, 0]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(3, 'cursor-line')).toBe true
        expect(lineNumberHasClass(4, 'cursor-line')).toBe false

    it "does not apply .cursor-line to the last line of a selection if it's empty", ->
      editor.setSelectedScreenRange([[3, 4], [5, 0]])
      waitsForNextDOMUpdate()
      runs ->
        expect(lineNumberHasClass(3, 'cursor-line')).toBe true
        expect(lineNumberHasClass(4, 'cursor-line')).toBe true
        expect(lineNumberHasClass(5, 'cursor-line')).toBe false

    it "applies .cursor-line decorations for lines containing the cursor in non-empty selections", ->
      editor.setCursorScreenPosition([4, 4])
      waitsForNextDOMUpdate()
      runs ->
        expect(lineHasClass(3, 'cursor-line')).toBe false
        expect(lineHasClass(4, 'cursor-line')).toBe true
        expect(lineHasClass(5, 'cursor-line')).toBe false

        editor.setSelectedScreenRange([[3, 4], [4, 4]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineHasClass(2, 'cursor-line')).toBe false
        expect(lineHasClass(3, 'cursor-line')).toBe false
        expect(lineHasClass(4, 'cursor-line')).toBe false
        expect(lineHasClass(5, 'cursor-line')).toBe false

    it "applies .cursor-line-no-selection to line numbers for rows containing the cursor when the selection is empty", ->
      editor.setCursorScreenPosition([4, 4])
      waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe true

        editor.setSelectedScreenRange([[3, 4], [4, 4]])
        waitsForNextDOMUpdate()

      runs ->
        expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe false

  describe "height", ->
    describe "when the wrapper view has an explicit height", ->
      it "does not assign a height on the component node", ->
        wrapperNode.style.height = '200px'
        component.measureDimensions()
        waitsForNextDOMUpdate()

        runs ->
          expect(componentNode.style.height).toBe ''

    describe "when the wrapper view does not have an explicit height", ->
      it "assigns a height on the component node based on the editor's content", ->
        expect(wrapperNode.style.height).toBe ''
        expect(componentNode.style.height).toBe editor.getScreenLineCount() * lineHeightInPixels + 'px'

  describe "when the 'mini' property is true", ->
    beforeEach ->
      editor.setMini(true)
      waitsForNextDOMUpdate()

    it "does not render the gutter", ->
      expect(componentNode.querySelector('.gutter')).toBeNull()

    it "adds the 'mini' class to the wrapper view", ->
      expect(wrapperNode.classList.contains('mini')).toBe true

    it "does not have an opaque background on lines", ->
      expect(component.linesComponent.getDomNode().getAttribute('style')).not.toContain 'background-color'

    it "does not render invisible characters", ->
      atom.config.set('editor.invisibles', eol: 'E')
      atom.config.set('editor.showInvisibles', true)
      expect(component.lineNodeForScreenRow(0).textContent).toBe 'var quicksort = function () {'

    it "does not assign an explicit line-height on the editor contents", ->
      expect(componentNode.style.lineHeight).toBe ''

    it "does not apply cursor-line decorations", ->
      expect(component.lineNodeForScreenRow(0).classList.contains('cursor-line')).toBe false

  describe "when placholderText is specified", ->
    it "renders the placeholder text when the buffer is empty", ->
      editor.setPlaceholderText('Hello World')
      expect(componentNode.querySelector('.placeholder-text')).toBeNull()
      editor.setText('')
      waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.placeholder-text').textContent).toBe "Hello World"
        editor.setText('hey')
        waitsForNextDOMUpdate()

      runs ->
        expect(componentNode.querySelector('.placeholder-text')).toBeNull()

  describe "grammar data attributes", ->
    it "adds and updates the grammar data attribute based on the current grammar", ->
      expect(wrapperNode.dataset.grammar).toBe 'source js'
      editor.setGrammar(atom.grammars.nullGrammar)
      expect(wrapperNode.dataset.grammar).toBe 'text plain null-grammar'

  describe "encoding data attributes", ->
    it "adds and updates the encoding data attribute based on the current encoding", ->
      expect(wrapperNode.dataset.encoding).toBe 'utf8'
      editor.setEncoding('utf16le')
      expect(wrapperNode.dataset.encoding).toBe 'utf16le'

  describe "detaching and reattaching the editor (regression)", ->
    it "does not throw an exception", ->
      wrapperNode.remove()
      jasmine.attachToDOM(wrapperNode)

      atom.commands.dispatch(wrapperNode, 'core:move-right')

      expect(editor.getCursorBufferPosition()).toEqual [0, 1]

  describe 'scoped config settings', ->
    [coffeeEditor, coffeeComponent] = []

    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')
      waitsForPromise ->
        atom.workspace.open('coffee.coffee', autoIndent: false).then (o) -> coffeeEditor = o

    afterEach: ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe 'soft wrap settings', ->
      beforeEach ->
        atom.config.set 'editor.softWrap', true, scopeSelector: '.source.coffee'
        atom.config.set 'editor.preferredLineLength', 17, scopeSelector: '.source.coffee'
        atom.config.set 'editor.softWrapAtPreferredLineLength', true, scopeSelector: '.source.coffee'

        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(20)
        coffeeEditor.setDefaultCharWidth(1)
        coffeeEditor.setEditorWidthInChars(20)

      it "wraps lines when editor.softWrap is true for a matching scope", ->
        expect(editor.lineTextForScreenRow(2)).toEqual '    if (items.length <= 1) return items;'
        expect(coffeeEditor.lineTextForScreenRow(3)).toEqual '    return items '

      it 'updates the wrapped lines when editor.preferredLineLength changes', ->
        atom.config.set 'editor.preferredLineLength', 20, scopeSelector: '.source.coffee'
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual '    return items if '

      it 'updates the wrapped lines when editor.softWrapAtPreferredLineLength changes', ->
        atom.config.set 'editor.softWrapAtPreferredLineLength', false, scopeSelector: '.source.coffee'
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual '    return items if '

      it 'updates the wrapped lines when editor.softWrap changes', ->
        atom.config.set 'editor.softWrap', false, scopeSelector: '.source.coffee'
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual '    return items if items.length <= 1'

        atom.config.set 'editor.softWrap', true, scopeSelector: '.source.coffee'
        expect(coffeeEditor.lineTextForScreenRow(3)).toEqual '    return items '

      it 'updates the wrapped lines when the grammar changes', ->
        editor.setGrammar(coffeeEditor.getGrammar())
        expect(editor.isSoftWrapped()).toBe true
        expect(editor.lineTextForScreenRow(0)).toEqual 'var quicksort = '

      describe '::isSoftWrapped()', ->
        it 'returns the correct value based on the scoped settings', ->
          expect(editor.isSoftWrapped()).toBe false
          expect(coffeeEditor.isSoftWrapped()).toBe true

    describe 'invisibles settings', ->
      [jsInvisibles, coffeeInvisibles] = []
      beforeEach ->
        jsInvisibles =
          eol: 'J'
          space: 'A'
          tab: 'V'
          cr: 'A'

        coffeeInvisibles =
          eol: 'C'
          space: 'O'
          tab: 'F'
          cr: 'E'

        atom.config.set 'editor.showInvisibles', true, scopeSelector: '.source.js'
        atom.config.set 'editor.invisibles', jsInvisibles, scopeSelector: '.source.js'

        atom.config.set 'editor.showInvisibles', false, scopeSelector: '.source.coffee'
        atom.config.set 'editor.invisibles', coffeeInvisibles, scopeSelector: '.source.coffee'

        editor.setText " a line with tabs\tand spaces \n"
        waitsForNextDOMUpdate()

      it "renders the invisibles when editor.showInvisibles is true for a given grammar", ->
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{jsInvisibles.space}a line with tabs#{jsInvisibles.tab}and spaces#{jsInvisibles.space}#{jsInvisibles.eol}"

      it "does not render the invisibles when editor.showInvisibles is false for a given grammar", ->
        editor.setGrammar(coffeeEditor.getGrammar())
        waitsForNextDOMUpdate()
        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe " a line with tabs and spaces "

      it "re-renders the invisibles when the invisible settings change", ->
        jsGrammar = editor.getGrammar()
        editor.setGrammar(coffeeEditor.getGrammar())
        atom.config.set 'editor.showInvisibles', true, scopeSelector: '.source.coffee'
        waitsForNextDOMUpdate()

        newInvisibles =
          eol: 'N'
          space: 'E'
          tab: 'W'
          cr: 'I'

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{coffeeInvisibles.space}a line with tabs#{coffeeInvisibles.tab}and spaces#{coffeeInvisibles.space}#{coffeeInvisibles.eol}"
          atom.config.set 'editor.invisibles', newInvisibles, scopeSelector: '.source.coffee'

        waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{newInvisibles.space}a line with tabs#{newInvisibles.tab}and spaces#{newInvisibles.space}#{newInvisibles.eol}"
          editor.setGrammar(jsGrammar)
          waitsForNextDOMUpdate()

        runs ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "#{jsInvisibles.space}a line with tabs#{jsInvisibles.tab}and spaces#{jsInvisibles.space}#{jsInvisibles.eol}"

    describe 'editor.showIndentGuide', ->
      beforeEach ->
        atom.config.set 'editor.showIndentGuide', true, scopeSelector: '.source.js'
        atom.config.set 'editor.showIndentGuide', false, scopeSelector: '.source.coffee'
        waitsForNextDOMUpdate()

      it "has an 'indent-guide' class when scoped editor.showIndentGuide is true, but not when scoped editor.showIndentGuide is false", ->
        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

        editor.setGrammar(coffeeEditor.getGrammar())
        waitsForNextDOMUpdate()

        runs ->
          line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
          expect(line1LeafNodes[0].textContent).toBe '  '
          expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe false
          expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

      it "removes the 'indent-guide' class when editor.showIndentGuide to false", ->
        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

        atom.config.set 'editor.showIndentGuide', false, scopeSelector: '.source.js'
        waitsForNextDOMUpdate()

        runs ->
          line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
          expect(line1LeafNodes[0].textContent).toBe '  '
          expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe false
          expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

  describe "autoscroll", ->
    beforeEach ->
      editor.setVerticalScrollMargin(2)
      editor.setHorizontalScrollMargin(2)
      component.setLineHeight("10px")
      component.setFontSize(17)
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        wrapperNode.setWidth(55)
        wrapperNode.setHeight(55)
        component.measureDimensions()
        waitsForNextDOMUpdate()

      runs ->
        component.presenter.setHorizontalScrollbarHeight(0)
        component.presenter.setVerticalScrollbarWidth(0)
        waitsForNextDOMUpdate()

    describe "when selecting buffer ranges", ->
      it "autoscrolls the selection if it is last unless the 'autoscroll' option is false", ->
        expect(wrapperNode.getScrollTop()).toBe 0

        editor.setSelectedBufferRange([[5, 6], [6, 8]])
        waitsForNextDOMUpdate()

        right = null
        runs ->
          right = wrapperNode.pixelPositionForBufferPosition([6, 8 + editor.getHorizontalScrollMargin()]).left
          expect(wrapperNode.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10
          expect(wrapperNode.getScrollRight()).toBeCloseTo right, 0

          editor.setSelectedBufferRange([[0, 0], [0, 0]])
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          expect(wrapperNode.getScrollLeft()).toBe 0

          editor.setSelectedBufferRange([[6, 6], [6, 8]])
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10
          expect(wrapperNode.getScrollRight()).toBeCloseTo right, 0

    describe "when adding selections for buffer ranges", ->
      it "autoscrolls to the added selection if needed", ->
        editor.addSelectionForBufferRange([[8, 10], [8, 15]])
        waitsForNextDOMUpdate()

        runs ->
          right = wrapperNode.pixelPositionForBufferPosition([8, 15]).left
          expect(wrapperNode.getScrollBottom()).toBe (9 * 10) + (2 * 10)
          expect(wrapperNode.getScrollRight()).toBeCloseTo(right + 2 * 10, 0)

    describe "when selecting lines containing cursors", ->
      it "autoscrolls to the selection", ->
        editor.setCursorScreenPosition([5, 6])
        waitsForNextDOMUpdate()
        runs ->
          wrapperNode.scrollToTop()
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.selectLinesContainingCursors()
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10

    describe "when inserting text", ->
      describe "when there are multiple empty selections on different lines", ->
        it "autoscrolls to the last cursor", ->
          editor.setCursorScreenPosition([1, 2], autoscroll: false)
          waitsForNextDOMUpdate()
          runs ->
            editor.addCursorAtScreenPosition([10, 4], autoscroll: false)
            waitsForNextDOMUpdate()
          runs ->
            expect(wrapperNode.getScrollTop()).toBe 0
            editor.insertText('a')
            waitsForNextDOMUpdate()
          runs ->
            expect(wrapperNode.getScrollTop()).toBe 75

    describe "when scrolled to cursor position", ->
      it "scrolls the last cursor into view, centering around the cursor if possible and the 'center' option isn't false", ->
        editor.setCursorScreenPosition([8, 8], autoscroll: false)
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          expect(wrapperNode.getScrollLeft()).toBe 0

          editor.scrollToCursorPosition()
          waitsForNextDOMUpdate()

        runs ->
          right = wrapperNode.pixelPositionForScreenPosition([8, 9 + editor.getHorizontalScrollMargin()]).left
          expect(wrapperNode.getScrollTop()).toBe (8.8 * 10) - 30
          expect(wrapperNode.getScrollBottom()).toBe (8.3 * 10) + 30
          expect(wrapperNode.getScrollRight()).toBeCloseTo right, 0

          wrapperNode.setScrollTop(0)
          editor.scrollToCursorPosition(center: false)
          expect(wrapperNode.getScrollTop()).toBe (7.8 - editor.getVerticalScrollMargin()) * 10
          expect(wrapperNode.getScrollBottom()).toBe (9.3 + editor.getVerticalScrollMargin()) * 10

    describe "moving cursors", ->
      it "scrolls down when the last cursor gets closer than ::verticalScrollMargin to the bottom of the editor", ->
        expect(wrapperNode.getScrollTop()).toBe 0
        expect(wrapperNode.getScrollBottom()).toBe 5.5 * 10

        editor.setCursorScreenPosition([2, 0])
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe 5.5 * 10

          editor.moveDown()
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe 6 * 10

          editor.moveDown()
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe 7 * 10

      it "scrolls up when the last cursor gets closer than ::verticalScrollMargin to the top of the editor", ->
        editor.setCursorScreenPosition([11, 0])

        waitsForNextDOMUpdate()
        runs ->
          wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
          waitsForNextDOMUpdate()
        runs ->
          editor.moveUp()
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollBottom()).toBe wrapperNode.getScrollHeight()
          editor.moveUp()
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 7 * 10
          editor.moveUp()
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 6 * 10

      it "scrolls right when the last cursor gets closer than ::horizontalScrollMargin to the right of the editor", ->
        expect(wrapperNode.getScrollLeft()).toBe 0
        expect(wrapperNode.getScrollRight()).toBe 5.5 * 10

        editor.setCursorScreenPosition([0, 2])
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollRight()).toBe 5.5 * 10

          editor.moveRight()
          waitsForNextDOMUpdate()

        margin = null
        runs ->
          margin = component.presenter.getHorizontalScrollMarginInPixels()
          right = wrapperNode.pixelPositionForScreenPosition([0, 4]).left + margin
          expect(wrapperNode.getScrollRight()).toBeCloseTo right, 0
          editor.moveRight()

        waitsForNextDOMUpdate()

        runs ->
          right = wrapperNode.pixelPositionForScreenPosition([0, 5]).left + margin
          expect(wrapperNode.getScrollRight()).toBeCloseTo right, 0

      it "scrolls left when the last cursor gets closer than ::horizontalScrollMargin to the left of the editor", ->
        wrapperNode.setScrollRight(wrapperNode.getScrollWidth())

        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollRight()).toBe wrapperNode.getScrollWidth()
          editor.setCursorScreenPosition([6, 62], autoscroll: false)
          waitsForNextDOMUpdate()

        runs ->
          editor.moveLeft()
          waitsForNextDOMUpdate()

        margin = null
        runs ->
          margin = component.presenter.getHorizontalScrollMarginInPixels()
          left = wrapperNode.pixelPositionForScreenPosition([6, 61]).left - margin
          expect(wrapperNode.getScrollLeft()).toBeCloseTo left, 0
          editor.moveLeft()
          waitsForNextDOMUpdate()

        runs ->
          left = wrapperNode.pixelPositionForScreenPosition([6, 60]).left - margin
          expect(wrapperNode.getScrollLeft()).toBeCloseTo left, 0

      it "scrolls down when inserting lines makes the document longer than the editor's height", ->
        editor.setCursorScreenPosition([13, Infinity])
        editor.insertNewline()
        waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe 14 * 10
          editor.insertNewline()
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollBottom()).toBe 15 * 10

      it "autoscrolls to the cursor when it moves due to undo", ->
        editor.insertText('abc')
        wrapperNode.setScrollTop(Infinity)
        waitsForNextDOMUpdate()

        runs ->
          editor.undo()
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0

      it "doesn't scroll when the cursor moves into the visible area", ->
        editor.setCursorBufferPosition([0, 0])
        waitsForNextDOMUpdate()

        runs ->
          wrapperNode.setScrollTop(40)
          waitsForNextDOMUpdate()

        runs ->
          editor.setCursorBufferPosition([6, 0])
          waitsForNextDOMUpdate()

        runs ->
          expect(wrapperNode.getScrollTop()).toBe 40

      it "honors the autoscroll option on cursor and selection manipulation methods", ->
        expect(wrapperNode.getScrollTop()).toBe 0
        editor.addCursorAtScreenPosition([11, 11], autoscroll: false)
        waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.addCursorAtBufferPosition([11, 11], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.setCursorScreenPosition([11, 11], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.setCursorBufferPosition([11, 11], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.addSelectionForBufferRange([[11, 11], [11, 11]], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.addSelectionForScreenRange([[11, 11], [11, 12]], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.setSelectedBufferRange([[11, 0], [11, 1]], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.setSelectedScreenRange([[11, 0], [11, 6]], autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.clearSelections(autoscroll: false)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.addSelectionForScreenRange([[0, 0], [0, 4]])
          waitsForNextDOMUpdate()
        runs ->
          editor.getCursors()[0].setScreenPosition([11, 11], autoscroll: true)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBeGreaterThan 0
          editor.getCursors()[0].setBufferPosition([0, 0], autoscroll: true)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0
          editor.getSelections()[0].setScreenRange([[11, 0], [11, 4]], autoscroll: true)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBeGreaterThan 0
          editor.getSelections()[0].setBufferRange([[0, 0], [0, 4]], autoscroll: true)
          waitsForNextDOMUpdate()
        runs ->
          expect(wrapperNode.getScrollTop()).toBe 0

  describe "::getVisibleRowRange()", ->
    beforeEach ->
      wrapperNode.style.height = lineHeightInPixels * 8 + "px"
      component.measureDimensions()
      waitsForNextDOMUpdate()

    it "returns the first and the last visible rows", ->
      component.setScrollTop(0)
      waitsForNextDOMUpdate()

      runs ->
        expect(component.getVisibleRowRange()).toEqual [0, 9]

    it "ends at last buffer row even if there's more space available", ->
      wrapperNode.style.height = lineHeightInPixels * 13 + "px"
      component.measureDimensions()
      waitsForNextDOMUpdate()

      runs ->
        component.setScrollTop(60)
        waitsForNextDOMUpdate()

      runs ->
        expect(component.getVisibleRowRange()).toEqual [0, 13]

  describe "middle mouse paste on Linux", ->
    originalPlatform = null

    beforeEach ->
      originalPlatform = process.platform
      Object.defineProperty process, 'platform', value: 'linux'

    afterEach ->
      Object.defineProperty process, 'platform', value: originalPlatform

    it "pastes the previously selected text at the clicked location", ->
      clipboardWrittenTo = false
      spyOn(require('ipc'), 'send').andCallFake (eventName, selectedText) ->
        if eventName is 'write-text-to-selection-clipboard'
          require('../src/safe-clipboard').writeText(selectedText, 'selection')
          clipboardWrittenTo = true

      atom.clipboard.write('')
      component.trackSelectionClipboard()
      editor.setSelectedBufferRange([[1, 6], [1, 10]])

      waitsFor ->
        clipboardWrittenTo

      runs ->
        componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([10, 0]), button: 1))
        componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([10, 0]), which: 2))
        expect(atom.clipboard.read()).toBe 'sort'
        expect(editor.lineTextForBufferRow(10)).toBe 'sort'

  buildMouseEvent = (type, properties...) ->
    properties = extend({bubbles: true, cancelable: true}, properties...)
    properties.detail ?= 1
    event = new MouseEvent(type, properties)
    Object.defineProperty(event, 'which', get: -> properties.which) if properties.which?
    if properties.target?
      Object.defineProperty(event, 'target', get: -> properties.target)
      Object.defineProperty(event, 'srcObject', get: -> properties.target)
    event

  clientCoordinatesForScreenPosition = (screenPosition) ->
    positionOffset = wrapperNode.pixelPositionForScreenPosition(screenPosition)
    scrollViewClientRect = componentNode.querySelector('.scroll-view').getBoundingClientRect()
    clientX = scrollViewClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = scrollViewClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    {clientX, clientY}

  clientCoordinatesForScreenRowInGutter = (screenRow) ->
    positionOffset = wrapperNode.pixelPositionForScreenPosition([screenRow, Infinity])
    gutterClientRect = componentNode.querySelector('.gutter').getBoundingClientRect()
    clientX = gutterClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = gutterClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    {clientX, clientY}

  lineAndLineNumberHaveClass = (screenRow, klass) ->
    lineHasClass(screenRow, klass) and lineNumberHasClass(screenRow, klass)

  lineNumberHasClass = (screenRow, klass) ->
    component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)

  lineNumberForBufferRowHasClass = (bufferRow, klass) ->
    screenRow = editor.displayBuffer.screenRowForBufferRow(bufferRow)
    component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)

  lineHasClass = (screenRow, klass) ->
    component.lineNodeForScreenRow(screenRow).classList.contains(klass)

  getLeafNodes = (node) ->
    if node.children.length > 0
      flatten(toArray(node.children).map(getLeafNodes))
    else
      [node]

  waitsForNextDOMUpdate = ->
    waitsForPromise -> atom.views.getNextUpdatePromise()

  waitsForAnimationFrame = ->
    waitsFor 'next animation frame', (done) -> requestAnimationFrame(done)
