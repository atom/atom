_ = require 'underscore-plus'
{extend, flatten, toArray, last} = _

TextEditorView = require '../src/text-editor-view'
TextEditorComponent = require '../src/text-editor-component'
nbsp = String.fromCharCode(160)

describe "TextEditorComponent", ->
  [contentNode, editor, wrapperView, wrapperNode, component, componentNode, verticalScrollbarNode, horizontalScrollbarNode] = []
  [lineHeightInPixels, charWidth, nextAnimationFrame, noAnimationFrame, lineOverdrawMargin] = []

  beforeEach ->
    lineOverdrawMargin = 2

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    runs ->
      spyOn(window, "setInterval").andCallFake window.fakeSetInterval
      spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

      noAnimationFrame = -> throw new Error('No animation frame requested')
      nextAnimationFrame = noAnimationFrame

      spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
        nextAnimationFrame = ->
          nextAnimationFrame = noAnimationFrame
          fn()

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      contentNode = document.querySelector('#jasmine-content')
      contentNode.style.width = '1000px'

      wrapperView = new TextEditorView(editor, {lineOverdrawMargin})
      wrapperView.attachToDom()
      wrapperNode = wrapperView.element
      wrapperNode.setUpdatedSynchronously(false)

      {component} = wrapperView
      component.setFontFamily('monospace')
      component.setLineHeight(1.3)
      component.setFontSize(20)

      lineHeightInPixels = editor.getLineHeightInPixels()
      charWidth = editor.getDefaultCharWidth()
      componentNode = component.domNode
      verticalScrollbarNode = componentNode.querySelector('.vertical-scrollbar')
      horizontalScrollbarNode = componentNode.querySelector('.horizontal-scrollbar')

      component.measureDimensions()
      nextAnimationFrame()

  afterEach ->
    contentNode.style.width = ''

  describe "async updates", ->
    it "handles corrupted state gracefully", ->
      # trigger state updates, e.g. presenter.updateLinesState
      editor.insertNewline()

      # simulate state corruption
      component.presenter.startRow = -1
      component.presenter.endRow = 9999

      expect(nextAnimationFrame).not.toThrow()

  describe "line rendering", ->
    it "renders the currently-visible lines plus the overdraw margin", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      linesNode = componentNode.querySelector('.lines')
      expect(linesNode.style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"
      expect(componentNode.querySelectorAll('.line').length).toBe 6 + 2 # no margin above
      expect(component.lineNodeForScreenRow(0).textContent).toBe editor.tokenizedLineForScreenRow(0).text
      expect(component.lineNodeForScreenRow(0).offsetTop).toBe 0
      expect(component.lineNodeForScreenRow(5).textContent).toBe editor.tokenizedLineForScreenRow(5).text
      expect(component.lineNodeForScreenRow(5).offsetTop).toBe 5 * lineHeightInPixels

      verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()

      expect(linesNode.style['-webkit-transform']).toBe "translate3d(0px, #{-4.5 * lineHeightInPixels}px, 0px)"
      expect(componentNode.querySelectorAll('.line').length).toBe 6 + 4 # margin above and below
      expect(component.lineNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(2).textContent).toBe editor.tokenizedLineForScreenRow(2).text
      expect(component.lineNodeForScreenRow(9).offsetTop).toBe 9 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(9).textContent).toBe editor.tokenizedLineForScreenRow(9).text

    it "updates the top position of subsequent lines when lines are inserted or removed", ->
      editor.getBuffer().deleteRows(0, 1)
      nextAnimationFrame()

      lineNodes = componentNode.querySelectorAll('.line')
      expect(component.lineNodeForScreenRow(0).offsetTop).toBe 0
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels

      editor.getBuffer().insert([0, 0], '\n\n')
      nextAnimationFrame()

      lineNodes = componentNode.querySelectorAll('.line')
      expect(component.lineNodeForScreenRow(0).offsetTop).toBe 0 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(3).offsetTop).toBe 3 * lineHeightInPixels
      expect(component.lineNodeForScreenRow(4).offsetTop).toBe 4 * lineHeightInPixels

    it "updates the lines when lines are inserted or removed above the rendered row range", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      verticalScrollbarNode.scrollTop = 5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()
      buffer = editor.getBuffer()

      buffer.insert([0, 0], '\n\n')
      nextAnimationFrame()
      expect(component.lineNodeForScreenRow(3).textContent).toBe editor.tokenizedLineForScreenRow(3).text

      buffer.delete([[0, 0], [3, 0]])
      nextAnimationFrame()
      expect(component.lineNodeForScreenRow(3).textContent).toBe editor.tokenizedLineForScreenRow(3).text

    it "updates the top position of lines when the line height changes", ->
      initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setLineHeight(2)
      nextAnimationFrame()

      newLineHeightInPixels = editor.getLineHeightInPixels()
      expect(newLineHeightInPixels).not.toBe initialLineHeightInPixels
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * newLineHeightInPixels

    it "updates the top position of lines when the font size changes", ->
      initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setFontSize(10)
      nextAnimationFrame()

      newLineHeightInPixels = editor.getLineHeightInPixels()
      expect(newLineHeightInPixels).not.toBe initialLineHeightInPixels
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * newLineHeightInPixels

    xit "updates the top position of lines when the font family changes", ->
      # Can't find a font that changes the line height, but we think one might exist
      linesComponent = component.refs.lines
      spyOn(linesComponent, 'measureLineHeightAndDefaultCharWidth').andCallFake -> editor.setLineHeightInPixels(10)

      initialLineHeightInPixels = editor.getLineHeightInPixels()
      component.setFontFamily('sans-serif')
      nextAnimationFrame()

      expect(linesComponent.measureLineHeightAndDefaultCharWidth).toHaveBeenCalled()
      newLineHeightInPixels = editor.getLineHeightInPixels()
      expect(newLineHeightInPixels).not.toBe initialLineHeightInPixels
      expect(component.lineNodeForScreenRow(1).offsetTop).toBe 1 * newLineHeightInPixels

    it "renders the .lines div at the full height of the editor if there aren't enough lines to scroll vertically", ->
      editor.setText('')
      wrapperNode.style.height = '300px'
      component.measureDimensions()
      nextAnimationFrame()

      linesNode = componentNode.querySelector('.lines')
      expect(linesNode.offsetHeight).toBe 300

    it "assigns the width of each line so it extends across the full width of the editor", ->
      gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      scrollViewNode = componentNode.querySelector('.scroll-view')
      lineNodes = componentNode.querySelectorAll('.line')

      componentNode.style.width = gutterWidth + (30 * charWidth) + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      expect(editor.getScrollWidth()).toBeGreaterThan scrollViewNode.offsetWidth

      # At the time of writing, using width: 100% to achieve the full-width
      # lines caused full-screen repaints after switching away from an editor
      # and back again Please ensure you don't cause a performance regression if
      # you change this behavior.
      for lineNode in lineNodes
        expect(lineNode.style.width).toBe editor.getScrollWidth() + 'px'

      componentNode.style.width = gutterWidth + editor.getScrollWidth() + 100 + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      scrollViewWidth = scrollViewNode.offsetWidth

      for lineNode in lineNodes
        expect(lineNode.style.width).toBe scrollViewWidth + 'px'

    it "renders an nbsp on empty lines when no line-ending character is defined", ->
      atom.config.set("editor.showInvisibles", false)
      expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

    it "gives the lines div the same background color as the editor to improve GPU performance", ->
      linesNode = componentNode.querySelector('.lines')
      backgroundColor = getComputedStyle(wrapperNode).backgroundColor
      expect(linesNode.style.backgroundColor).toBe backgroundColor

      wrapperNode.style.backgroundColor = 'rgb(255, 0, 0)'

      advanceClock(atom.views.documentPollingInterval)
      nextAnimationFrame()
      expect(linesNode.style.backgroundColor).toBe 'rgb(255, 0, 0)'

    it "applies .leading-whitespace for lines with leading spaces and/or tabs", ->
      editor.setText(' a')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe false

      editor.setText('\ta')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe false

    it "applies .trailing-whitespace for lines with trailing spaces and/or tabs", ->
      editor.setText(' ')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

      editor.setText('\t')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

      editor.setText('a ')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

      editor.setText('a\t')
      nextAnimationFrame()

      leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
      expect(leafNodes[0].classList.contains('trailing-whitespace')).toBe true
      expect(leafNodes[0].classList.contains('leading-whitespace')).toBe false

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
        nextAnimationFrame()

      it "re-renders the lines when the showInvisibles config option changes", ->
        editor.setText " a line with tabs\tand spaces \n"
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

        atom.config.set("editor.showInvisibles", false)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe " a line with tabs and spaces "

        atom.config.set("editor.showInvisibles", true)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

      it "displays leading/trailing spaces, tabs, and newlines as visible characters", ->
        editor.setText " a line with tabs\tand spaces \n"
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{invisibles.space}a line with tabs#{invisibles.tab}and spaces#{invisibles.space}#{invisibles.eol}"

        leafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(leafNodes[0].classList.contains('invisible-character')).toBe true
        expect(leafNodes[leafNodes.length - 1].classList.contains('invisible-character')).toBe true

      it "displays newlines as their own token outside of the other tokens' scopeDescriptor", ->
        editor.setText "var\n"
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).innerHTML).toBe "<span class=\"source js\"><span class=\"storage modifier js\">var</span></span><span class=\"invisible-character\">#{invisibles.eol}</span>"

      it "displays trailing carriage returns using a visible, non-empty value", ->
        editor.setText "a line that ends with a carriage return\r\n"
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "a line that ends with a carriage return#{invisibles.cr}#{invisibles.eol}"

      it "renders invisible line-ending characters on empty lines", ->
        expect(component.lineNodeForScreenRow(10).textContent).toBe invisibles.eol

      it "renders an nbsp on empty lines when the line-ending character is an empty string", ->
        atom.config.set("editor.invisibles", eol: '')
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

      it "renders an nbsp on empty lines when the line-ending character is false", ->
        atom.config.set("editor.invisibles", eol: false)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).textContent).toBe nbsp

      it "interleaves invisible line-ending characters with indent guides on empty lines", ->
        atom.config.set "editor.showIndentGuide", true
        nextAnimationFrame()

        editor.setTextInBufferRange([[10, 0], [11, 0]], "\r\n", normalizeLineEndings: false)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span><span class="invisible-character">E</span></span>'

        editor.setTabLength(3)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span><span class="invisible-character">E</span> </span>'

        editor.setTabLength(1)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span></span><span class="indent-guide"><span class="invisible-character">E</span></span>'

        editor.setTextInBufferRange([[9, 0], [9, Infinity]], ' ')
        editor.setTextInBufferRange([[11, 0], [11, Infinity]], ' ')
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(10).innerHTML).toBe '<span class="indent-guide"><span class="invisible-character">C</span></span><span class="invisible-character">E</span>'

      describe "when soft wrapping is enabled", ->
        beforeEach ->
          editor.setText "a line that wraps \n"
          editor.setSoftWrapped(true)
          nextAnimationFrame()
          componentNode.style.width = 16 * charWidth + editor.getVerticalScrollbarWidth() + 'px'
          component.measureDimensions()
          nextAnimationFrame()

        it "doesn't show end of line invisibles at the end of wrapped lines", ->
          expect(component.lineNodeForScreenRow(0).textContent).toBe "a line that "
          expect(component.lineNodeForScreenRow(1).textContent).toBe "wraps#{invisibles.space}#{invisibles.eol}"

    describe "when indent guides are enabled", ->
      beforeEach ->
        atom.config.set "editor.showIndentGuide", true
        nextAnimationFrame()

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
        nextAnimationFrame()

        line2LeafNodes = getLeafNodes(component.lineNodeForScreenRow(2))

        expect(line2LeafNodes.length).toBe 2
        expect(line2LeafNodes[0].textContent).toBe '  '
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[1].textContent).toBe '  '
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true

      it "renders indent guides correctly on lines containing only whitespace", ->
        editor.getBuffer().insert([1, Infinity], '\n      ')
        nextAnimationFrame()

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
        nextAnimationFrame()

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
        nextAnimationFrame()

        line0LeafNodes = getLeafNodes(component.lineNodeForScreenRow(0))
        expect(line0LeafNodes[0].textContent).toBe '  '
        expect(line0LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line0LeafNodes[1].textContent).toBe '  '
        expect(line0LeafNodes[1].classList.contains('indent-guide')).toBe false

      it "updates the indent guides on empty lines preceding an indentation change", ->
        editor.getBuffer().insert([12, 0], '\n')
        nextAnimationFrame()
        editor.getBuffer().insert([13, 0], '    ')
        nextAnimationFrame()

        line12LeafNodes = getLeafNodes(component.lineNodeForScreenRow(12))
        expect(line12LeafNodes[0].textContent).toBe '  '
        expect(line12LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line12LeafNodes[1].textContent).toBe '  '
        expect(line12LeafNodes[1].classList.contains('indent-guide')).toBe true

      it "updates the indent guides on empty lines following an indentation change", ->
        editor.getBuffer().insert([12, 2], '\n')
        nextAnimationFrame()
        editor.getBuffer().insert([12, 0], '    ')
        nextAnimationFrame()

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
        nextAnimationFrame()

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
        nextAnimationFrame()
        expect(wrapperNode.pixelPositionForScreenPosition([0, Infinity]).left).toEqual 2 * charWidth

    describe "when there is a fold", ->
      it "renders a fold marker on the folded line", ->
        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()

        editor.foldBufferRow(4)
        nextAnimationFrame()
        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeTruthy()

        editor.unfoldBufferRow(4)
        nextAnimationFrame()
        foldedLineNode = component.lineNodeForScreenRow(4)
        expect(foldedLineNode.querySelector('.fold-marker')).toBeFalsy()

  describe "gutter rendering", ->
    it "renders the currently-visible line numbers", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(componentNode.querySelectorAll('.line-number').length).toBe 6 + 2 + 1 # line overdraw margin below + dummy line number
      expect(component.lineNumberNodeForScreenRow(0).textContent).toBe "#{nbsp}1"
      expect(component.lineNumberNodeForScreenRow(5).textContent).toBe "#{nbsp}6"

      verticalScrollbarNode.scrollTop = 2.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()

      expect(componentNode.querySelectorAll('.line-number').length).toBe 6 + 4 + 1 # line overdraw margin above/below + dummy line number

      expect(component.lineNumberNodeForScreenRow(2).textContent).toBe "#{nbsp}3"
      expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(7).textContent).toBe "#{nbsp}8"
      expect(component.lineNumberNodeForScreenRow(7).offsetTop).toBe 7 * lineHeightInPixels

    it "updates the translation of subsequent line numbers when lines are inserted or removed", ->
      editor.getBuffer().insert([0, 0], '\n\n')
      nextAnimationFrame()

      lineNumberNodes = componentNode.querySelectorAll('.line-number')
      expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe 0
      expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe 3 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe 4 * lineHeightInPixels

      editor.getBuffer().insert([0, 0], '\n\n')
      nextAnimationFrame()

      expect(component.lineNumberNodeForScreenRow(0).offsetTop).toBe 0
      expect(component.lineNumberNodeForScreenRow(1).offsetTop).toBe 1 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(2).offsetTop).toBe 2 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(3).offsetTop).toBe 3 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(4).offsetTop).toBe 4 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(5).offsetTop).toBe 5 * lineHeightInPixels
      expect(component.lineNumberNodeForScreenRow(6).offsetTop).toBe 6 * lineHeightInPixels

    it "renders • characters for soft-wrapped lines", ->
      editor.setSoftWrapped(true)
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(componentNode.querySelectorAll('.line-number').length).toBe 6 + lineOverdrawMargin + 1 # 1 dummy line componentNode
      expect(component.lineNumberNodeForScreenRow(0).textContent).toBe "#{nbsp}1"
      expect(component.lineNumberNodeForScreenRow(1).textContent).toBe "#{nbsp}•"
      expect(component.lineNumberNodeForScreenRow(2).textContent).toBe "#{nbsp}2"
      expect(component.lineNumberNodeForScreenRow(3).textContent).toBe "#{nbsp}•"
      expect(component.lineNumberNodeForScreenRow(4).textContent).toBe "#{nbsp}3"
      expect(component.lineNumberNodeForScreenRow(5).textContent).toBe "#{nbsp}•"

    it "pads line numbers to be right-justified based on the maximum number of line number digits", ->
      editor.getBuffer().setText([1..10].join('\n'))
      nextAnimationFrame()
      for screenRow in [0..8]
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{nbsp}#{screenRow + 1}"
      expect(component.lineNumberNodeForScreenRow(9).textContent).toBe "10"

      gutterNode = componentNode.querySelector('.gutter')
      initialGutterWidth = gutterNode.offsetWidth

      # Removes padding when the max number of digits goes down
      editor.getBuffer().delete([[1, 0], [2, 0]])
      nextAnimationFrame()
      for screenRow in [0..8]
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{screenRow + 1}"
      expect(gutterNode.offsetWidth).toBeLessThan initialGutterWidth

      # Increases padding when the max number of digits goes up
      editor.getBuffer().insert([0, 0], '\n\n')
      nextAnimationFrame()
      for screenRow in [0..8]
        expect(component.lineNumberNodeForScreenRow(screenRow).textContent).toBe "#{nbsp}#{screenRow + 1}"
      expect(component.lineNumberNodeForScreenRow(9).textContent).toBe "10"
      expect(gutterNode.offsetWidth).toBe initialGutterWidth

    it "renders the .line-numbers div at the full height of the editor even if it's taller than its content", ->
      wrapperNode.style.height = componentNode.offsetHeight + 100 + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      expect(componentNode.querySelector('.line-numbers').offsetHeight).toBe componentNode.offsetHeight

    it "applies the background color of the gutter or the editor to the line numbers to improve GPU performance", ->
      gutterNode = componentNode.querySelector('.gutter')
      lineNumbersNode = gutterNode.querySelector('.line-numbers')
      {backgroundColor} = getComputedStyle(wrapperNode)
      expect(lineNumbersNode.style.backgroundColor).toBe backgroundColor

      # favor gutter color if it's assigned
      gutterNode.style.backgroundColor = 'rgb(255, 0, 0)'
      advanceClock(atom.views.documentPollingInterval)
      nextAnimationFrame()
      expect(lineNumbersNode.style.backgroundColor).toBe 'rgb(255, 0, 0)'

    it "hides or shows the gutter based on the '::isGutterVisible' property on the model and the global 'editor.showLineNumbers' config setting", ->
      expect(component.gutterComponent?).toBe true

      editor.setGutterVisible(false)
      nextAnimationFrame()

      expect(componentNode.querySelector('.gutter')).toBeNull()

      atom.config.set("editor.showLineNumbers", false)
      nextAnimationFrame()

      expect(componentNode.querySelector('.gutter')).toBeNull()

      editor.setGutterVisible(true)
      nextAnimationFrame()

      expect(componentNode.querySelector('.gutter')).toBeNull()

      atom.config.set("editor.showLineNumbers", true)
      nextAnimationFrame()

      expect(componentNode.querySelector('.gutter')).toBeDefined()
      expect(component.lineNumberNodeForScreenRow(3)?).toBe true

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
          nextAnimationFrame()
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
          nextAnimationFrame()
          expect(lineNumberHasClass(11, 'foldable')).toBe true

          editor.undo()
          nextAnimationFrame()
          expect(lineNumberHasClass(11, 'foldable')).toBe false

        it "adds, updates and removes the folded class on the correct line number componentNodes", ->
          editor.foldBufferRow(4)
          nextAnimationFrame()
          expect(lineNumberHasClass(4, 'folded')).toBe true

          editor.getBuffer().insert([0, 0], '\n')
          nextAnimationFrame()
          expect(lineNumberHasClass(4, 'folded')).toBe false
          expect(lineNumberHasClass(5, 'folded')).toBe true

          editor.unfoldBufferRow(5)
          nextAnimationFrame()
          expect(lineNumberHasClass(5, 'folded')).toBe false

        describe "when soft wrapping is enabled", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            nextAnimationFrame()
            componentNode.style.width = 16 * charWidth + editor.getVerticalScrollbarWidth() + 'px'
            component.measureDimensions()
            nextAnimationFrame()

          it "doesn't add the foldable class for soft-wrapped lines", ->
            expect(lineNumberHasClass(0, 'foldable')).toBe true
            expect(lineNumberHasClass(1, 'foldable')).toBe false

      describe "mouse interactions with fold indicators", ->
        [gutterNode] = []

        buildClickEvent = (target) ->
          buildMouseEvent('click', {target})

        beforeEach ->
          gutterNode = componentNode.querySelector('.gutter')

        it "folds and unfolds the block represented by the fold indicator when clicked", ->
          expect(lineNumberHasClass(1, 'folded')).toBe false

          lineNumber = component.lineNumberNodeForScreenRow(1)
          target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))
          nextAnimationFrame()
          expect(lineNumberHasClass(1, 'folded')).toBe true

          lineNumber = component.lineNumberNodeForScreenRow(1)
          target = lineNumber.querySelector('.icon-right')
          target.dispatchEvent(buildClickEvent(target))
          nextAnimationFrame()
          expect(lineNumberHasClass(1, 'folded')).toBe false

        it "does not fold when the line number componentNode is clicked", ->
          lineNumber = component.lineNumberNodeForScreenRow(1)
          lineNumber.dispatchEvent(buildClickEvent(lineNumber))
          expect(nextAnimationFrame).toBe noAnimationFrame
          expect(lineNumberHasClass(1, 'folded')).toBe false

  describe "cursor rendering", ->
    it "renders the currently visible cursors", ->
      cursor1 = editor.getLastCursor()
      cursor1.setScreenPosition([0, 5], autoscroll: false)

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 1
      expect(cursorNodes[0].offsetHeight).toBe lineHeightInPixels
      expect(cursorNodes[0].offsetWidth).toBe charWidth
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{5 * charWidth}px, #{0 * lineHeightInPixels}px)"

      cursor2 = editor.addCursorAtScreenPosition([8, 11], autoscroll: false)
      cursor3 = editor.addCursorAtScreenPosition([4, 10], autoscroll: false)
      nextAnimationFrame()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 2
      expect(cursorNodes[0].offsetTop).toBe 0
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{5 * charWidth}px, #{0 * lineHeightInPixels}px)"
      expect(cursorNodes[1].style['-webkit-transform']).toBe "translate(#{10 * charWidth}px, #{4 * lineHeightInPixels}px)"

      verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()
      horizontalScrollbarNode.scrollLeft = 3.5 * charWidth
      horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 2
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{10 * charWidth}px, #{4 * lineHeightInPixels}px)"
      expect(cursorNodes[1].style['-webkit-transform']).toBe "translate(#{11 * charWidth}px, #{8 * lineHeightInPixels}px)"

      editor.onDidChangeCursorPosition cursorMovedListener = jasmine.createSpy('cursorMovedListener')
      cursor3.setScreenPosition([4, 11], autoscroll: false)
      nextAnimationFrame()
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{11 * charWidth}px, #{4 * lineHeightInPixels}px)"
      expect(cursorMovedListener).toHaveBeenCalled()

      cursor3.destroy()
      nextAnimationFrame()
      cursorNodes = componentNode.querySelectorAll('.cursor')

      expect(cursorNodes.length).toBe 1
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{11 * charWidth}px, #{8 * lineHeightInPixels}px)"

    it "accounts for character widths when positioning cursors", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setCursorScreenPosition([0, 16])
      nextAnimationFrame()

      cursor = componentNode.querySelector('.cursor')
      cursorRect = cursor.getBoundingClientRect()

      cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.storage.type.function.js').firstChild
      range = document.createRange()
      range.setStart(cursorLocationTextNode, 0)
      range.setEnd(cursorLocationTextNode, 1)
      rangeRect = range.getBoundingClientRect()

      expect(cursorRect.left).toBe rangeRect.left
      expect(cursorRect.width).toBe rangeRect.width

    it "accounts for the width of paired characters when positioning cursors", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setText('he\u0301y') # e with an accent mark
      editor.setCursorBufferPosition([0, 3])
      nextAnimationFrame()

      cursor = componentNode.querySelector('.cursor')
      cursorRect = cursor.getBoundingClientRect()

      cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.source.js').firstChild
      range = document.createRange()
      range.setStart(cursorLocationTextNode, 3)
      range.setEnd(cursorLocationTextNode, 4)
      rangeRect = range.getBoundingClientRect()

      expect(cursorRect.left).toBe rangeRect.left
      expect(cursorRect.width).toBe rangeRect.width

    it "positions cursors correctly after character widths are changed via a stylesheet change", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setCursorScreenPosition([0, 16])
      nextAnimationFrame()

      atom.styles.addStyleSheet """
        .function.js {
          font-weight: bold;
        }
      """, context: 'atom-text-editor'
      nextAnimationFrame() # update based on new measurements

      cursor = componentNode.querySelector('.cursor')
      cursorRect = cursor.getBoundingClientRect()

      cursorLocationTextNode = component.lineNodeForScreenRow(0).querySelector('.storage.type.function.js').firstChild
      range = document.createRange()
      range.setStart(cursorLocationTextNode, 0)
      range.setEnd(cursorLocationTextNode, 1)
      rangeRect = range.getBoundingClientRect()

      expect(cursorRect.left).toBe rangeRect.left
      expect(cursorRect.width).toBe rangeRect.width

      atom.themes.removeStylesheet('test')

    it "sets the cursor to the default character width at the end of a line", ->
      editor.setCursorScreenPosition([0, Infinity])
      nextAnimationFrame()
      cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.offsetWidth).toBe charWidth

    it "gives the cursor a non-zero width even if it's inside atomic tokens", ->
      editor.setCursorScreenPosition([1, 0])
      nextAnimationFrame()
      cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.offsetWidth).toBe charWidth

    it "blinks cursors when they aren't moving", ->
      cursorsNode = componentNode.querySelector('.cursors')

      wrapperNode.focus()
      nextAnimationFrame()
      expect(cursorsNode.classList.contains('blink-off')).toBe false

      advanceClock(component.cursorBlinkPeriod / 2)
      nextAnimationFrame()
      expect(cursorsNode.classList.contains('blink-off')).toBe true

      advanceClock(component.cursorBlinkPeriod / 2)
      nextAnimationFrame()
      expect(cursorsNode.classList.contains('blink-off')).toBe false

      # Stop blinking after moving the cursor
      editor.moveRight()
      nextAnimationFrame()
      expect(cursorsNode.classList.contains('blink-off')).toBe false

      advanceClock(component.cursorBlinkResumeDelay)
      advanceClock(component.cursorBlinkPeriod / 2)
      nextAnimationFrame()
      expect(cursorsNode.classList.contains('blink-off')).toBe true

    it "does not render cursors that are associated with non-empty selections", ->
      editor.setSelectedScreenRange([[0, 4], [4, 6]])
      editor.addCursorAtScreenPosition([6, 8])
      nextAnimationFrame()

      cursorNodes = componentNode.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 1
      expect(cursorNodes[0].style['-webkit-transform']).toBe "translate(#{8 * charWidth}px, #{6 * lineHeightInPixels}px)"

    it "updates cursor positions when the line height changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setLineHeight(2)
      nextAnimationFrame()
      cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.style['-webkit-transform']).toBe "translate(#{10 * editor.getDefaultCharWidth()}px, #{editor.getLineHeightInPixels()}px)"

    it "updates cursor positions when the font size changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setFontSize(10)
      nextAnimationFrame()
      cursorNode = componentNode.querySelector('.cursor')
      expect(cursorNode.style['-webkit-transform']).toBe "translate(#{10 * editor.getDefaultCharWidth()}px, #{editor.getLineHeightInPixels()}px)"

    it "updates cursor positions when the font family changes", ->
      editor.setCursorBufferPosition([1, 10])
      component.setFontFamily('sans-serif')
      nextAnimationFrame()
      cursorNode = componentNode.querySelector('.cursor')

      {left} = wrapperNode.pixelPositionForScreenPosition([1, 10])
      expect(cursorNode.style['-webkit-transform']).toBe "translate(#{left}px, #{editor.getLineHeightInPixels()}px)"

  describe "selection rendering", ->
    [scrollViewNode, scrollViewClientLeft] = []

    beforeEach ->
      scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left

    it "renders 1 region for 1-line selections", ->
      # 1-line selection
      editor.setSelectedScreenRange([[1, 6], [1, 10]])
      nextAnimationFrame()
      regions = componentNode.querySelectorAll('.selection .region')

      expect(regions.length).toBe 1
      regionRect = regions[0].getBoundingClientRect()
      expect(regionRect.top).toBe 1 * lineHeightInPixels
      expect(regionRect.height).toBe 1 * lineHeightInPixels
      expect(regionRect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(regionRect.width).toBe 4 * charWidth

    it "renders 2 regions for 2-line selections", ->
      editor.setSelectedScreenRange([[1, 6], [2, 10]])
      nextAnimationFrame()
      regions = componentNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe 2

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(region1Rect.right).toBe scrollViewNode.getBoundingClientRect().right

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 1 * lineHeightInPixels
      expect(region2Rect.left).toBe scrollViewClientLeft + 0
      expect(region2Rect.width).toBe 10 * charWidth

    it "renders 3 regions for selections with more than 2 lines", ->
      editor.setSelectedScreenRange([[1, 6], [5, 10]])
      nextAnimationFrame()
      regions = componentNode.querySelectorAll('.selection .region')
      expect(regions.length).toBe 3

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(region1Rect.right).toBe scrollViewNode.getBoundingClientRect().right

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 3 * lineHeightInPixels
      expect(region2Rect.left).toBe scrollViewClientLeft + 0
      expect(region2Rect.right).toBe scrollViewNode.getBoundingClientRect().right

      region3Rect = regions[2].getBoundingClientRect()
      expect(region3Rect.top).toBe 5 * lineHeightInPixels
      expect(region3Rect.height).toBe 1 * lineHeightInPixels
      expect(region3Rect.left).toBe scrollViewClientLeft + 0
      expect(region3Rect.width).toBe 10 * charWidth

    it "does not render empty selections", ->
      editor.addSelectionForBufferRange([[2, 2], [2, 2]])
      nextAnimationFrame()
      expect(editor.getSelections()[0].isEmpty()).toBe true
      expect(editor.getSelections()[1].isEmpty()).toBe true

      expect(componentNode.querySelectorAll('.selection').length).toBe 0

    it "updates selections when the line height changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setLineHeight(2)
      nextAnimationFrame()
      selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()

    it "updates selections when the font size changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontSize(10)
      nextAnimationFrame()
      selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()
      expect(selectionNode.offsetLeft).toBe 6 * editor.getDefaultCharWidth()

    it "updates selections when the font family changes", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]])
      component.setFontFamily('sans-serif')
      nextAnimationFrame()
      selectionNode = componentNode.querySelector('.region')
      expect(selectionNode.offsetTop).toBe editor.getLineHeightInPixels()
      expect(selectionNode.offsetLeft).toBe wrapperNode.pixelPositionForScreenPosition([1, 6]).left

    it "will flash the selection when flash:true is passed to editor::setSelectedBufferRange", ->
      editor.setSelectedBufferRange([[1, 6], [1, 10]], flash: true)
      nextAnimationFrame()
      selectionNode = componentNode.querySelector('.selection')
      expect(selectionNode.classList.contains('flash')).toBe true

      advanceClock editor.selectionFlashDuration
      expect(selectionNode.classList.contains('flash')).toBe false

      editor.setSelectedBufferRange([[1, 5], [1, 7]], flash: true)
      nextAnimationFrame()
      expect(selectionNode.classList.contains('flash')).toBe true

  describe "line decoration rendering", ->
    [marker, decoration, decorationParams] = []

    beforeEach ->
      marker = editor.displayBuffer.markBufferRange([[2, 13], [3, 15]], invalidate: 'inside')
      decorationParams = {type: ['line-number', 'line'], class: 'a'}
      decoration = editor.decorateMarker(marker, decorationParams)
      nextAnimationFrame()

    it "applies line decoration classes to lines and line numbers", ->
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true

      # Shrink editor vertically
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      # Add decorations that are out of range
      marker2 = editor.displayBuffer.markBufferRange([[9, 0], [9, 0]])
      editor.decorateMarker(marker2, type: ['line-number', 'line'], class: 'b')
      nextAnimationFrame()

      # Scroll decorations into view
      verticalScrollbarNode.scrollTop = 2.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()
      expect(lineAndLineNumberHaveClass(9, 'b')).toBe true

      # Fold a line to move the decorations
      editor.foldBufferRow(5)
      nextAnimationFrame()
      expect(lineAndLineNumberHaveClass(9, 'b')).toBe false
      expect(lineAndLineNumberHaveClass(6, 'b')).toBe true

    it "only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
      editor.setText("a line that wraps, ok")
      editor.setSoftWrapped(true)
      componentNode.style.width = 16 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      marker.destroy()
      marker = editor.markBufferRange([[0, 0], [0, 2]])
      editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'b')
      nextAnimationFrame()
      expect(lineNumberHasClass(0, 'b')).toBe true
      expect(lineNumberHasClass(1, 'b')).toBe false

      marker.setBufferRange([[0, 0], [0, Infinity]])
      nextAnimationFrame()
      expect(lineNumberHasClass(0, 'b')).toBe true
      expect(lineNumberHasClass(1, 'b')).toBe true

    it "updates decorations when markers move", ->
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

      editor.getBuffer().insert([0, 0], '\n')
      nextAnimationFrame()
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(5, 'a')).toBe false

      marker.setBufferRange([[4, 4], [6, 4]])
      nextAnimationFrame()
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(5, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(6, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(7, 'a')).toBe false

    it "remove decoration classes and unsubscribes from markers decorations are removed", ->
      expect(marker.getSubscriptionCount('changed'))
      decoration.destroy()
      nextAnimationFrame()
      expect(lineNumberHasClass(1, 'a')).toBe false
      expect(lineNumberHasClass(2, 'a')).toBe false
      expect(lineNumberHasClass(3, 'a')).toBe false
      expect(lineNumberHasClass(4, 'a')).toBe false
      expect(marker.getSubscriptionCount('changed')).toBe 0

    it "removes decorations when their marker is invalidated", ->
      editor.getBuffer().insert([3, 2], 'n')
      nextAnimationFrame()
      expect(marker.isValid()).toBe false
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

      editor.undo()
      nextAnimationFrame()
      expect(marker.isValid()).toBe true
      expect(lineAndLineNumberHaveClass(1, 'a')).toBe false
      expect(lineAndLineNumberHaveClass(2, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(3, 'a')).toBe true
      expect(lineAndLineNumberHaveClass(4, 'a')).toBe false

    it "removes decorations when their marker is destroyed", ->
      marker.destroy()
      nextAnimationFrame()
      expect(lineNumberHasClass(1, 'a')).toBe false
      expect(lineNumberHasClass(2, 'a')).toBe false
      expect(lineNumberHasClass(3, 'a')).toBe false
      expect(lineNumberHasClass(4, 'a')).toBe false

    describe "when the decoration's 'onlyHead' property is true", ->
      it "only applies the decoration's class to lines containing the marker's head", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-head', onlyHead: true)
        nextAnimationFrame()
        expect(lineAndLineNumberHaveClass(1, 'only-head')).toBe false
        expect(lineAndLineNumberHaveClass(2, 'only-head')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'only-head')).toBe true
        expect(lineAndLineNumberHaveClass(4, 'only-head')).toBe false

    describe "when the decoration's 'onlyEmpty' property is true", ->
      it "only applies the decoration when its marker is empty", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-empty', onlyEmpty: true)
        nextAnimationFrame()
        expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe false

        marker.clearTail()
        nextAnimationFrame()
        expect(lineAndLineNumberHaveClass(2, 'only-empty')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'only-empty')).toBe true

    describe "when the decoration's 'onlyNonEmpty' property is true", ->
      it "only applies the decoration when its marker is non-empty", ->
        editor.decorateMarker(marker, type: ['line-number', 'line'], class: 'only-non-empty', onlyNonEmpty: true)
        nextAnimationFrame()
        expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe true
        expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe true

        marker.clearTail()
        nextAnimationFrame()
        expect(lineAndLineNumberHaveClass(2, 'only-non-empty')).toBe false
        expect(lineAndLineNumberHaveClass(3, 'only-non-empty')).toBe false

  describe "highlight decoration rendering", ->
    [marker, decoration, decorationParams, scrollViewClientLeft] = []
    beforeEach ->
      scrollViewClientLeft = componentNode.querySelector('.scroll-view').getBoundingClientRect().left
      marker = editor.displayBuffer.markBufferRange([[2, 13], [3, 15]], invalidate: 'inside')
      decorationParams = {type: 'highlight', class: 'test-highlight'}
      decoration = editor.decorateMarker(marker, decorationParams)
      nextAnimationFrame()

    it "does not render highlights for off-screen lines until they come on-screen", ->
      wrapperNode.style.height = 2.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      marker = editor.displayBuffer.markBufferRange([[9, 2], [9, 4]], invalidate: 'inside')
      editor.decorateMarker(marker, type: 'highlight', class: 'some-highlight')
      nextAnimationFrame()

      # Should not be rendering range containing the marker
      expect(component.presenter.endRow).toBeLessThan 9

      regions = componentNode.querySelectorAll('.some-highlight .region')

      # Nothing when outside the rendered row range
      expect(regions.length).toBe 0

      verticalScrollbarNode.scrollTop = 4.5 * lineHeightInPixels
      verticalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()

      regions = componentNode.querySelectorAll('.some-highlight .region')

      expect(regions.length).toBe 1
      regionRect = regions[0].style
      expect(regionRect.top).toBe 9 * lineHeightInPixels + 'px'
      expect(regionRect.height).toBe 1 * lineHeightInPixels + 'px'
      expect(regionRect.left).toBe 2 * charWidth + 'px'
      expect(regionRect.width).toBe 2 * charWidth + 'px'

    it "renders highlights decoration's marker is added", ->
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 2

    it "removes highlights when a decoration is removed", ->
      decoration.destroy()
      nextAnimationFrame()
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 0

    it "does not render a highlight that is within a fold", ->
      editor.foldBufferRow(1)
      nextAnimationFrame()
      expect(componentNode.querySelectorAll('.test-highlight').length).toBe 0

    it "removes highlights when a decoration's marker is destroyed", ->
      marker.destroy()
      nextAnimationFrame()
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 0

    it "only renders highlights when a decoration's marker is valid", ->
      editor.getBuffer().insert([3, 2], 'n')
      nextAnimationFrame()

      expect(marker.isValid()).toBe false
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 0

      editor.getBuffer().undo()
      nextAnimationFrame()

      expect(marker.isValid()).toBe true
      regions = componentNode.querySelectorAll('.test-highlight .region')
      expect(regions.length).toBe 2

    it "allows multiple space-delimited decoration classes", ->
      decoration.setProperties(type: 'highlight', class: 'foo bar')
      nextAnimationFrame()
      expect(componentNode.querySelectorAll('.foo.bar').length).toBe 1
      decoration.setProperties(type: 'highlight', class: 'bar baz')
      nextAnimationFrame()
      expect(componentNode.querySelectorAll('.bar.baz').length).toBe 1

    it "renders classes on the regions directly if 'deprecatedRegionClass' option is defined", ->
      decoration = editor.decorateMarker(marker, type: 'highlight', class: 'test-highlight', deprecatedRegionClass: 'test-highlight-region')
      nextAnimationFrame()

      regions = componentNode.querySelectorAll('.test-highlight .region.test-highlight-region')
      expect(regions.length).toBe 2

    describe "when flashing a decoration via Decoration::flash()", ->
      highlightNode = null
      beforeEach ->
        highlightNode = componentNode.querySelector('.test-highlight')

      it "adds and removes the flash class specified in ::flash", ->
        expect(highlightNode.classList.contains('flash-class')).toBe false

        decoration.flash('flash-class', 10)
        nextAnimationFrame()
        expect(highlightNode.classList.contains('flash-class')).toBe true

        advanceClock(10)
        expect(highlightNode.classList.contains('flash-class')).toBe false

      describe "when ::flash is called again before the first has finished", ->
        it "removes the class from the decoration highlight before adding it for the second ::flash call", ->
          decoration.flash('flash-class', 10)
          nextAnimationFrame()
          expect(highlightNode.classList.contains('flash-class')).toBe true
          advanceClock(2)

          decoration.flash('flash-class', 10)
          nextAnimationFrame()

          # Removed for 1 frame to force CSS transition to restart
          expect(highlightNode.classList.contains('flash-class')).toBe false

          nextAnimationFrame()
          expect(highlightNode.classList.contains('flash-class')).toBe true

          advanceClock(10)
          expect(highlightNode.classList.contains('flash-class')).toBe false

    describe "when a decoration's marker moves", ->
      it "moves rendered highlights when the buffer is changed", ->
        regionStyle = componentNode.querySelector('.test-highlight .region').style
        originalTop = parseInt(regionStyle.top)

        editor.getBuffer().insert([0, 0], '\n')
        nextAnimationFrame()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        newTop = parseInt(regionStyle.top)

        expect(newTop).toBe originalTop + lineHeightInPixels

      it "moves rendered highlights when the marker is manually moved", ->
        regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe 2 * lineHeightInPixels

        marker.setBufferRange([[5, 8], [5, 13]])
        nextAnimationFrame()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe 5 * lineHeightInPixels

    describe "when a decoration is updated via Decoration::update", ->
      it "renders the decoration's new params", ->
        expect(componentNode.querySelector('.test-highlight')).toBeTruthy()

        decoration.setProperties(type: 'highlight', class: 'new-test-highlight')
        nextAnimationFrame()

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
        nextAnimationFrame()

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe item

        decoration.destroy()
        nextAnimationFrame()

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe null

    describe "when the marker is not empty", ->
      it "renders at the head of the marker by default", ->
        marker = editor.displayBuffer.markBufferRange([[2, 5], [2, 10]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', item})
        nextAnimationFrame()
        nextAnimationFrame()

        position = wrapperNode.pixelPositionForBufferPosition([2, 10])

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        expect(overlay.style.left).toBe position.left + gutterWidth + 'px'
        expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

    describe "positioning the overlay when near the edge of the editor", ->
      [itemWidth, itemHeight, windowWidth, windowHeight] = []
      beforeEach ->
        atom.storeWindowDimensions()

        itemWidth = 4 * editor.getDefaultCharWidth()
        itemHeight = 4 * editor.getLineHeightInPixels()

        windowWidth = gutterWidth + 30 * editor.getDefaultCharWidth()
        windowHeight = 10 * editor.getLineHeightInPixels()

        item.style.width = itemWidth + 'px'
        item.style.height = itemHeight + 'px'

        wrapperNode.style.width = windowWidth + 'px'
        wrapperNode.style.height = windowHeight + 'px'

        atom.setWindowDimensions({width: windowWidth, height: windowHeight})

        component.measureDimensions()
        component.measureWindowSize()
        nextAnimationFrame()

      afterEach ->
        atom.restoreWindowDimensions()

      it "slides horizontally left when near the right edge", ->
        marker = editor.displayBuffer.markBufferRange([[0, 26], [0, 26]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'overlay', item})
        nextAnimationFrame()
        nextAnimationFrame()

        position = wrapperNode.pixelPositionForBufferPosition([0, 26])

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        expect(overlay.style.left).toBe position.left + gutterWidth + 'px'
        expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

        editor.insertText('a')
        nextAnimationFrame()

        expect(overlay.style.left).toBe windowWidth - itemWidth + 'px'
        expect(overlay.style.top).toBe position.top + editor.getLineHeightInPixels() + 'px'

        editor.insertText('b')
        nextAnimationFrame()

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
      nextAnimationFrame()

      expect(editor.getCursorScreenPosition()).toEqual [0, 0]
      editor.setScrollTop(3 * lineHeightInPixels)
      editor.setScrollLeft(3 * charWidth)
      nextAnimationFrame()

      expect(inputNode.offsetTop).toBe 0
      expect(inputNode.offsetLeft).toBe 0

      # In bounds, not focused
      editor.setCursorBufferPosition([5, 4], autoscroll: false)
      nextAnimationFrame()
      expect(inputNode.offsetTop).toBe 0
      expect(inputNode.offsetLeft).toBe 0

      # In bounds and focused
      wrapperNode.focus() # updates via state change
      nextAnimationFrame()
      expect(inputNode.offsetTop).toBe (5 * lineHeightInPixels) - editor.getScrollTop()
      expect(inputNode.offsetLeft).toBe (4 * charWidth) - editor.getScrollLeft()

      # In bounds, not focused
      inputNode.blur() # updates via state change
      nextAnimationFrame()
      expect(inputNode.offsetTop).toBe 0
      expect(inputNode.offsetLeft).toBe 0

      # Out of bounds, not focused
      editor.setCursorBufferPosition([1, 2], autoscroll: false)
      nextAnimationFrame()
      expect(inputNode.offsetTop).toBe 0
      expect(inputNode.offsetLeft).toBe 0

      # Out of bounds, focused
      inputNode.focus() # updates via state change
      nextAnimationFrame()
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
        nextAnimationFrame()

        coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = -1
        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
        nextAnimationFrame()
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]

    describe "when the mouse is single-clicked below the last line", ->
      it "moves the cursor to the end of file buffer position", ->
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 0])
        height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        nextAnimationFrame()

        coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = height * 2
        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
        nextAnimationFrame()
        expect(editor.getCursorScreenPosition()).toEqual [0, 3]

    describe "when a non-folded line is single-clicked", ->
      describe "when no modifier keys are held down", ->
        it "moves the cursor to the nearest screen position", ->
          wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
          wrapperNode.style.width = 10 * charWidth + 'px'
          component.measureDimensions()
          editor.setScrollTop(3.5 * lineHeightInPixels)
          editor.setScrollLeft(2 * charWidth)
          nextAnimationFrame()

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8])))
          nextAnimationFrame()
          expect(editor.getCursorScreenPosition()).toEqual [4, 8]

      describe "when the shift key is held down", ->
        it "selects to the nearest screen position", ->
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), shiftKey: true))
          nextAnimationFrame()
          expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [5, 6]]

      describe "when the command key is held down", ->
        it "adds a cursor at the nearest screen position", ->
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), metaKey: true))
          nextAnimationFrame()
          expect(editor.getSelectedScreenRanges()).toEqual [[[3, 4], [3, 4]], [[5, 6], [5, 6]]]

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
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), which: 1))
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [10, 0]]

        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([12, 0]), which: 1))
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [10, 0]]

      it "stops selecting if the mouse is dragged into the dev tools", ->
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), which: 0))
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), which: 1))
        expect(nextAnimationFrame).toBe noAnimationFrame
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

      describe "when the editor is destroyed while dragging", ->
        it "cleans up the handlers for window.mouseup and window.mousemove", ->
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), which: 1))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), which: 1))
          nextAnimationFrame()

          spyOn(window, 'removeEventListener').andCallThrough()

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 10]), which: 1))
          editor.destroy()
          nextAnimationFrame()

          call.args.pop() for call in window.removeEventListener.calls
          expect(window.removeEventListener).toHaveBeenCalledWith('mouseup')
          expect(window.removeEventListener).toHaveBeenCalledWith('mousemove')

    describe "when a line is folded", ->
      beforeEach ->
        editor.foldBufferRow 4
        nextAnimationFrame()

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
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
          expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 0]]

      describe "when dragging upward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2)))
          expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 0]]

    describe "when the gutter is meta-clicked and dragged", ->
      beforeEach ->
        editor.setSelectedScreenRange([[3, 0], [3, 2]])

      describe "when dragging downward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [7, 0]]]

        it "merges overlapping selections", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[2, 0], [7, 0]]]

      describe "when dragging upward", ->
        it "selects the rows between the start and end of the drag", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(4), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[3, 0], [3, 2]], [[4, 0], [7, 0]]]

        it "merges overlapping selections", ->
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), metaKey: true))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          nextAnimationFrame()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[2, 0], [7, 0]]]

    describe "when the gutter is shift-clicked and dragged", ->
      describe "when the shift-click is below the existing selection's tail", ->
        describe "when dragging downward", ->
          it "selects the rows between the existing selection's tail and the end of the drag", ->
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [9, 0]]

        describe "when dragging upward", ->
          it "selects the rows between the end of the drag and the tail of the existing selection", ->
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[4, 4], [6, 0]]

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [4, 4]]

      describe "when the shift-click is above the existing selection's tail", ->
        describe "when dragging upward", ->
          it "selects the rows between the end of the drag and the tail of the existing selection", ->
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[1, 0], [4, 4]]

        describe "when dragging downward", ->
          it "selects the rows between the existing selection's tail and the end of the drag", ->
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [3, 4]]

            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            nextAnimationFrame()
            expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [9, 0]]

    describe "when soft wrap is enabled", ->
      beforeEach ->
        gutterNode = componentNode.querySelector('.gutter')

        editor.setSoftWrapped(true)
        nextAnimationFrame()
        componentNode.style.width = 21 * charWidth + editor.getVerticalScrollbarWidth() + 'px'
        component.measureDimensions()
        nextAnimationFrame()

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
          it "selects to the beginning of the buffer row following the clicked buffer row", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), shiftKey: true))
            expect(editor.getSelectedScreenRange()).toEqual [[7, 4], [16, 0]]

      describe "when the gutter is clicked and dragged", ->
        describe "when dragging downward", ->
          it "selects the buffer rows between the start and end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
            expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [10, 0]]

        describe "when dragging upward", ->
          it "selects the buffer rows between the start and end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(1)))
            expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [10, 0]]

      describe "when the gutter is meta-clicked and dragged", ->
        beforeEach ->
          editor.setSelectedScreenRange([[7, 4], [7, 6]])

        describe "when dragging downward", ->
          it "selects the buffer rows between the start and end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3), metaKey: true))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(3), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[7, 4], [7, 6]], [[0, 0], [5, 0]]]

          it "merges overlapping selections", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7), metaKey: true))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(7), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[0, 0], [10, 0]]]

        describe "when dragging upward", ->
          it "selects the buffer rows between the start and end of the drag", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11), metaKey: true))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(11), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[7, 4], [7, 6]], [[10, 0], [19, 0]]]

          it "merges overlapping selections", ->
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), metaKey: true))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(9), metaKey: true))
            nextAnimationFrame()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(9), metaKey: true))
            expect(editor.getSelectedScreenRanges()).toEqual [[[5, 0], [19, 0]]]

      describe "when the gutter is shift-clicked and dragged", ->
        describe "when the shift-click is below the existing selection's tail", ->
          describe "when dragging downward", ->
            it "selects the buffer rows between the existing selection's tail and the end of the drag", ->
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11)))
              nextAnimationFrame()
              expect(editor.getSelectedScreenRange()).toEqual [[1, 4], [16, 0]]

          describe "when dragging upward", ->
            it "selects the buffer rows between the end of the drag and the tail of the existing selection", ->
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
              nextAnimationFrame()
              expect(editor.getSelectedScreenRange()).toEqual [[1, 4], [10, 0]]

        describe "when the shift-click is above the existing selection's tail", ->
          describe "when dragging upward", ->
            it "selects the buffer rows between the end of the drag and the tail of the existing selection", ->
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(3), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
              nextAnimationFrame()
              expect(editor.getSelectedScreenRange()).toEqual [[0, 0], [7, 4]]

          describe "when dragging downward", ->
            it "selects the buffer rows between the existing selection's tail and the end of the drag", ->
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), shiftKey: true))

              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3)))
              nextAnimationFrame()
              expect(editor.getSelectedScreenRange()).toEqual [[2, 0], [7, 4]]

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
      nextAnimationFrame()
      expect(componentNode.classList.contains('is-focused')).toBe true
      expect(wrapperView.hasClass('is-focused')).toBe true
      inputNode.blur()
      nextAnimationFrame()
      expect(componentNode.classList.contains('is-focused')).toBe false
      expect(wrapperView.hasClass('is-focused')).toBe false

  describe "selection handling", ->
    cursor = null

    beforeEach ->
      cursor = editor.getLastCursor()
      cursor.setScreenPosition([0, 0])

    it "adds the 'has-selection' class to the editor when there is a selection", ->
      expect(componentNode.classList.contains('has-selection')).toBe false

      editor.selectDown()
      nextAnimationFrame()
      expect(componentNode.classList.contains('has-selection')).toBe true

      cursor.moveDown()
      nextAnimationFrame()
      expect(componentNode.classList.contains('has-selection')).toBe false

  describe "scrolling", ->
    it "updates the vertical scrollbar when the scrollTop is changed in the model", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(verticalScrollbarNode.scrollTop).toBe 0

      editor.setScrollTop(10)
      nextAnimationFrame()
      expect(verticalScrollbarNode.scrollTop).toBe 10

    it "updates the horizontal scrollbar and the x transform of the lines based on the scrollLeft of the model", ->
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      linesNode = componentNode.querySelector('.lines')
      expect(linesNode.style['-webkit-transform']).toBe "translate3d(0px, 0px, 0px)"
      expect(horizontalScrollbarNode.scrollLeft).toBe 0

      editor.setScrollLeft(100)
      nextAnimationFrame()
      expect(linesNode.style['-webkit-transform']).toBe "translate3d(-100px, 0px, 0px)"
      expect(horizontalScrollbarNode.scrollLeft).toBe 100

    it "updates the scrollLeft of the model when the scrollLeft of the horizontal scrollbar changes", ->
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(editor.getScrollLeft()).toBe 0
      horizontalScrollbarNode.scrollLeft = 100
      horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      nextAnimationFrame()

      expect(editor.getScrollLeft()).toBe 100

    it "does not obscure the last line with the horizontal scrollbar", ->
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      editor.setScrollBottom(editor.getScrollHeight())
      nextAnimationFrame()
      lastLineNode = component.lineNodeForScreenRow(editor.getLastScreenRow())
      bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      topOfHorizontalScrollbar = horizontalScrollbarNode.getBoundingClientRect().top
      expect(bottomOfLastLine).toBe topOfHorizontalScrollbar

      # Scroll so there's no space below the last line when the horizontal scrollbar disappears
      wrapperNode.style.width = 100 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      bottomOfEditor = componentNode.getBoundingClientRect().bottom
      expect(bottomOfLastLine).toBe bottomOfEditor

    it "does not obscure the last character of the longest line with the vertical scrollbar", ->
      wrapperNode.style.height = 7 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      editor.setScrollLeft(Infinity)
      nextAnimationFrame()

      rightOfLongestLine = component.lineNodeForScreenRow(6).querySelector('.line > span:last-child').getBoundingClientRect().right
      leftOfVerticalScrollbar = verticalScrollbarNode.getBoundingClientRect().left
      expect(Math.round(rightOfLongestLine)).toBe leftOfVerticalScrollbar - 1 # Leave 1 px so the cursor is visible on the end of the line

    it "only displays dummy scrollbars when scrollable in that direction", ->
      expect(verticalScrollbarNode.style.display).toBe 'none'
      expect(horizontalScrollbarNode.style.display).toBe 'none'

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(verticalScrollbarNode.style.display).toBe ''
      expect(horizontalScrollbarNode.style.display).toBe 'none'

      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(verticalScrollbarNode.style.display).toBe ''
      expect(horizontalScrollbarNode.style.display).toBe ''

      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(verticalScrollbarNode.style.display).toBe 'none'
      expect(horizontalScrollbarNode.style.display).toBe ''

    it "makes the dummy scrollbar divs only as tall/wide as the actual scrollbars", ->
      wrapperNode.style.height = 4 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      atom.styles.addStyleSheet """
        ::-webkit-scrollbar {
          width: 8px;
          height: 8px;
        }
      """, context: 'atom-text-editor'

      nextAnimationFrame() # handle stylesheet change event
      nextAnimationFrame() # perform requested update

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
      nextAnimationFrame()
      expect(verticalScrollbarNode.style.bottom).toBe '0px'
      expect(horizontalScrollbarNode.style.right).toBe verticalScrollbarNode.offsetWidth + 'px'
      expect(scrollbarCornerNode.style.display).toBe 'none'

      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      expect(verticalScrollbarNode.style.bottom).toBe horizontalScrollbarNode.offsetHeight + 'px'
      expect(horizontalScrollbarNode.style.right).toBe verticalScrollbarNode.offsetWidth + 'px'
      expect(scrollbarCornerNode.style.display).toBe ''

      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      nextAnimationFrame()
      expect(verticalScrollbarNode.style.bottom).toBe horizontalScrollbarNode.offsetHeight + 'px'
      expect(horizontalScrollbarNode.style.right).toBe '0px'
      expect(scrollbarCornerNode.style.display).toBe 'none'

    it "accounts for the width of the gutter in the scrollWidth of the horizontal scrollbar", ->
      gutterNode = componentNode.querySelector('.gutter')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      expect(horizontalScrollbarNode.scrollWidth).toBe editor.getScrollWidth()
      expect(horizontalScrollbarNode.style.left).toBe '0px'

  describe "mousewheel events", ->
    beforeEach ->
      atom.config.set('editor.scrollSensitivity', 100)

    describe "updating scrollTop and scrollLeft", ->
      beforeEach ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        nextAnimationFrame()

      it "updates the scrollLeft or scrollTop on mousewheel events depending on which delta is greater (x or y)", ->
        expect(verticalScrollbarNode.scrollTop).toBe 0
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -5, wheelDeltaY: -10))
        nextAnimationFrame()
        expect(verticalScrollbarNode.scrollTop).toBe 10
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -15, wheelDeltaY: -5))
        nextAnimationFrame()
        expect(verticalScrollbarNode.scrollTop).toBe 10
        expect(horizontalScrollbarNode.scrollLeft).toBe 15

      it "updates the scrollLeft or scrollTop according to the scroll sensitivity", ->
        atom.config.set('editor.scrollSensitivity', 50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -5, wheelDeltaY: -10))
        nextAnimationFrame()
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -15, wheelDeltaY: -5))
        nextAnimationFrame()
        expect(verticalScrollbarNode.scrollTop).toBe 5
        expect(horizontalScrollbarNode.scrollLeft).toBe 7

      it "uses the previous scrollSensitivity when the value is not an int", ->
        atom.config.set('editor.scrollSensitivity', 'nope')
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -10))
        nextAnimationFrame()
        expect(verticalScrollbarNode.scrollTop).toBe 10

      it "parses negative scrollSensitivity values at the minimum", ->
        atom.config.set('editor.scrollSensitivity', -50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -10))
        nextAnimationFrame()
        expect(verticalScrollbarNode.scrollTop).toBe 1

    describe "when the mousewheel event's target is a line", ->
      it "keeps the line on the DOM if it is scrolled off-screen", ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()

        lineNode = componentNode.querySelector('.line')
        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -500)
        Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
        componentNode.dispatchEvent(wheelEvent)
        nextAnimationFrame()

        expect(componentNode.contains(lineNode)).toBe true

      it "does not set the mouseWheelScreenRow if scrolling horizontally", ->
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()

        lineNode = componentNode.querySelector('.line')
        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 10, wheelDeltaY: 0)
        Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
        componentNode.dispatchEvent(wheelEvent)
        nextAnimationFrame()

        expect(component.presenter.mouseWheelScreenRow).toBe null

      it "clears the mouseWheelScreenRow after a delay even if the event does not cause scrolling", ->
        expect(editor.getScrollTop()).toBe 0

        lineNode = componentNode.querySelector('.line')
        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: 10)
        Object.defineProperty(wheelEvent, 'target', get: -> lineNode)
        componentNode.dispatchEvent(wheelEvent)

        expect(editor.getScrollTop()).toBe 0

        expect(component.presenter.mouseWheelScreenRow).toBe 0
        advanceClock(component.presenter.stoppedScrollingDelay)
        expect(component.presenter.mouseWheelScreenRow).toBe null

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

        lineNumberNode = componentNode.querySelectorAll('.line-number')[1]
        wheelEvent = new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -500)
        Object.defineProperty(wheelEvent, 'target', get: -> lineNumberNode)
        componentNode.dispatchEvent(wheelEvent)
        nextAnimationFrame()

        expect(componentNode.contains(lineNumberNode)).toBe true

    it "only prevents the default action of the mousewheel event if it actually lead to scrolling", ->
      spyOn(WheelEvent::, 'preventDefault').andCallThrough()

      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * charWidth + 'px'
      component.measureDimensions()
      nextAnimationFrame()

      # try to scroll past the top, which is impossible
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: 50))
      expect(editor.getScrollTop()).toBe 0
      expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

      # scroll to the bottom in one huge event
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -3000))
      nextAnimationFrame()
      maxScrollTop = editor.getScrollTop()
      expect(WheelEvent::preventDefault).toHaveBeenCalled()
      WheelEvent::preventDefault.reset()

      # try to scroll past the bottom, which is impossible
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 0, wheelDeltaY: -30))
      expect(editor.getScrollTop()).toBe maxScrollTop
      expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

      # try to scroll past the left side, which is impossible
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: 50, wheelDeltaY: 0))
      expect(editor.getScrollLeft()).toBe 0
      expect(WheelEvent::preventDefault).not.toHaveBeenCalled()

      # scroll all the way right
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -3000, wheelDeltaY: 0))
      nextAnimationFrame()
      maxScrollLeft = editor.getScrollLeft()
      expect(WheelEvent::preventDefault).toHaveBeenCalled()
      WheelEvent::preventDefault.reset()

      # try to scroll past the right side, which is impossible
      componentNode.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -30, wheelDeltaY: 0))
      expect(editor.getScrollLeft()).toBe maxScrollLeft
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
      nextAnimationFrame()
      expect(editor.lineTextForBufferRow(0)).toBe 'xvar quicksort = function () {'

      componentNode.dispatchEvent(buildTextInputEvent(data: 'y', target: inputNode))
      nextAnimationFrame()
      expect(editor.lineTextForBufferRow(0)).toBe 'xyvar quicksort = function () {'

    it "replaces the last character if the length of the input's value doesn't increase, as occurs with the accented character menu", ->
      componentNode.dispatchEvent(buildTextInputEvent(data: 'u', target: inputNode))
      nextAnimationFrame()
      expect(editor.lineTextForBufferRow(0)).toBe 'uvar quicksort = function () {'

      # simulate the accented character suggestion's selection of the previous character
      inputNode.setSelectionRange(0, 1)
      componentNode.dispatchEvent(buildTextInputEvent(data: 'ü', target: inputNode))
      nextAnimationFrame()
      expect(editor.lineTextForBufferRow(0)).toBe 'üvar quicksort = function () {'

    it "does not handle input events when input is disabled", ->
      nextAnimationFrame = noAnimationFrame # This spec is flaky on the build machine, so this.
      component.setInputEnabled(false)
      componentNode.dispatchEvent(buildTextInputEvent(data: 'x', target: inputNode))
      expect(nextAnimationFrame).toBe noAnimationFrame
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

      currentTime += 100
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
          editor.setSelectedBufferRange [[0, 4], [0, 9]] # select 'quick'

        it "inserts the chosen completion", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var ssort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var sdsort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', target: inputNode))
          componentNode.dispatchEvent(buildTextInputEvent(data: '速度', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var 速度sort = function () {'

        it "reverts back to the original text when the completion helper is dismissed", ->
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', target: inputNode))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 's', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var ssort = function () {'

          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', data: 'sd', target: inputNode))
          expect(editor.lineTextForBufferRow(0)).toBe 'var sdsort = function () {'

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

  describe "hiding and showing the editor", ->
    describe "when the editor is hidden when it is mounted", ->
      it "defers measurement and rendering until the editor becomes visible", ->
        wrapperView.remove()

        hiddenParent = document.createElement('div')
        hiddenParent.style.display = 'none'
        contentNode.appendChild(hiddenParent)

        wrapperView = new TextEditorView(editor, {lineOverdrawMargin})
        wrapperNode = wrapperView.element
        wrapperView.appendTo(hiddenParent)

        {component} = wrapperView
        componentNode = component.domNode
        expect(componentNode.querySelectorAll('.line').length).toBe 0

        hiddenParent.style.display = 'block'
        advanceClock(atom.views.documentPollingInterval)

        expect(componentNode.querySelectorAll('.line').length).toBeGreaterThan 0

    describe "when the lineHeight changes while the editor is hidden", ->
      it "does not attempt to measure the lineHeightInPixels until the editor becomes visible again", ->
        wrapperView.hide()
        initialLineHeightInPixels = editor.getLineHeightInPixels()

        component.setLineHeight(2)
        expect(editor.getLineHeightInPixels()).toBe initialLineHeightInPixels

        wrapperView.show()
        expect(editor.getLineHeightInPixels()).not.toBe initialLineHeightInPixels

    describe "when the fontSize changes while the editor is hidden", ->
      it "does not attempt to measure the lineHeightInPixels or defaultCharWidth until the editor becomes visible again", ->
        wrapperView.hide()
        initialLineHeightInPixels = editor.getLineHeightInPixels()
        initialCharWidth = editor.getDefaultCharWidth()

        component.setFontSize(22)
        expect(editor.getLineHeightInPixels()).toBe initialLineHeightInPixels
        expect(editor.getDefaultCharWidth()).toBe initialCharWidth

        wrapperView.show()
        expect(editor.getLineHeightInPixels()).not.toBe initialLineHeightInPixels
        expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

      it "does not re-measure character widths until the editor is shown again", ->
        wrapperView.hide()

        component.setFontSize(22)
        editor.getBuffer().insert([0, 0], 'a') # regression test against atom/atom#3318

        wrapperView.show()
        editor.setCursorBufferPosition([0, Infinity])
        nextAnimationFrame()

        cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBe line0Right

    describe "when the fontFamily changes while the editor is hidden", ->
      it "does not attempt to measure the defaultCharWidth until the editor becomes visible again", ->
        wrapperView.hide()
        initialLineHeightInPixels = editor.getLineHeightInPixels()
        initialCharWidth = editor.getDefaultCharWidth()

        component.setFontFamily('sans-serif')
        expect(editor.getDefaultCharWidth()).toBe initialCharWidth

        wrapperView.show()
        expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

      it "does not re-measure character widths until the editor is shown again", ->
        wrapperView.hide()

        component.setFontFamily('sans-serif')

        wrapperView.show()
        editor.setCursorBufferPosition([0, Infinity])
        nextAnimationFrame()

        cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBe line0Right

    describe "when stylesheets change while the editor is hidden", ->
      afterEach ->
        atom.themes.removeStylesheet('test')

      it "does not re-measure character widths until the editor is shown again", ->
        atom.config.set('editor.fontFamily', 'sans-serif')

        wrapperView.hide()
        atom.themes.applyStylesheet 'test', """
          .function.js {
            font-weight: bold;
          }
        """

        wrapperView.show()
        editor.setCursorBufferPosition([0, Infinity])
        nextAnimationFrame()

        cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBe line0Right

    describe "when lines are changed while the editor is hidden", ->
      it "does not measure new characters until the editor is shown again", ->
        editor.setText('')
        wrapperView.hide()
        editor.setText('var z = 1')
        editor.setCursorBufferPosition([0, Infinity])
        nextAnimationFrame()
        wrapperView.show()
        expect(componentNode.querySelector('.cursor').style['-webkit-transform']).toBe "translate(#{9 * charWidth}px, 0px)"

  describe "soft wrapping", ->
    beforeEach ->
      editor.setSoftWrapped(true)
      nextAnimationFrame()

    it "updates the wrap location when the editor is resized", ->
      newHeight = 4 * editor.getLineHeightInPixels() + "px"
      expect(parseInt(newHeight)).toBeLessThan wrapperNode.offsetHeight
      wrapperNode.style.height = newHeight

      advanceClock(atom.views.documentPollingInterval)
      nextAnimationFrame()
      expect(componentNode.querySelectorAll('.line')).toHaveLength(4 + lineOverdrawMargin + 1)

      gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      componentNode.style.width = gutterWidth + 14 * charWidth + editor.getVerticalScrollbarWidth() + 'px'
      advanceClock(atom.views.documentPollingInterval)
      nextAnimationFrame()
      expect(componentNode.querySelector('.line').textContent).toBe "var quicksort "

    it "accounts for the scroll view's padding when determining the wrap location", ->
      scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewNode.style.paddingLeft = 20 + 'px'
      componentNode.style.width = 30 * charWidth + 'px'

      advanceClock(atom.views.documentPollingInterval)
      nextAnimationFrame()

      expect(component.lineNodeForScreenRow(0).textContent).toBe "var quicksort = "

  describe "default decorations", ->
    it "applies .cursor-line decorations for line numbers overlapping selections", ->
      editor.setCursorScreenPosition([4, 4])
      nextAnimationFrame()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe false
      expect(lineNumberHasClass(4, 'cursor-line')).toBe true
      expect(lineNumberHasClass(5, 'cursor-line')).toBe false

      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      nextAnimationFrame()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe true
      expect(lineNumberHasClass(4, 'cursor-line')).toBe true

      editor.setSelectedScreenRange([[3, 4], [4, 0]])
      nextAnimationFrame()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe true
      expect(lineNumberHasClass(4, 'cursor-line')).toBe false

    it "does not apply .cursor-line to the last line of a selection if it's empty", ->
      editor.setSelectedScreenRange([[3, 4], [5, 0]])
      nextAnimationFrame()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe true
      expect(lineNumberHasClass(4, 'cursor-line')).toBe true
      expect(lineNumberHasClass(5, 'cursor-line')).toBe false

    it "applies .cursor-line decorations for lines containing the cursor in non-empty selections", ->
      editor.setCursorScreenPosition([4, 4])
      nextAnimationFrame()
      expect(lineHasClass(3, 'cursor-line')).toBe false
      expect(lineHasClass(4, 'cursor-line')).toBe true
      expect(lineHasClass(5, 'cursor-line')).toBe false

      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      nextAnimationFrame()
      expect(lineHasClass(2, 'cursor-line')).toBe false
      expect(lineHasClass(3, 'cursor-line')).toBe false
      expect(lineHasClass(4, 'cursor-line')).toBe false
      expect(lineHasClass(5, 'cursor-line')).toBe false

    it "applies .cursor-line-no-selection to line numbers for rows containing the cursor when the selection is empty", ->
      editor.setCursorScreenPosition([4, 4])
      nextAnimationFrame()
      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe true

      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      nextAnimationFrame()
      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe false

  describe "height", ->
    describe "when the wrapper view has an explicit height", ->
      it "does not assign a height on the component node", ->
        wrapperNode.style.height = '200px'
        component.measureDimensions()
        nextAnimationFrame()
        expect(componentNode.style.height).toBe ''

    describe "when the wrapper view does not have an explicit height", ->
      it "assigns a height on the component node based on the editor's content", ->
        expect(wrapperNode.style.height).toBe ''
        expect(componentNode.style.height).toBe editor.getScreenLineCount() * lineHeightInPixels + 'px'

  describe "when the 'mini' property is true", ->
    beforeEach ->
      editor.setMini(true)
      nextAnimationFrame()

    it "does not render the gutter", ->
      expect(componentNode.querySelector('.gutter')).toBeNull()

    it "adds the 'mini' class to the wrapper view", ->
      expect(wrapperNode.classList.contains('mini')).toBe true

    it "does not have an opaque background on lines", ->
      expect(component.linesComponent.domNode.getAttribute('style')).not.toContain 'background-color'

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
      nextAnimationFrame()
      expect(componentNode.querySelector('.placeholder-text').textContent).toBe "Hello World"
      editor.setText('hey')
      nextAnimationFrame()
      expect(componentNode.querySelector('.placeholder-text')).toBeNull()

  describe "legacy editor compatibility", ->
    it "triggers the screen-lines-changed event before the editor:display-update event", ->
      editor.setSoftWrapped(true)

      callingOrder = []
      editor.onDidChange -> callingOrder.push 'screen-lines-changed'
      wrapperView.on 'editor:display-updated', -> callingOrder.push 'editor:display-updated'
      editor.insertText("HELLO! HELLO!\n HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! HELLO! ")
      nextAnimationFrame()

      expect(callingOrder).toEqual ['screen-lines-changed', 'editor:display-updated']

    it "works with the ::setEditorHeightInLines and ::setEditorWidthInChars helpers", ->
      setEditorHeightInLines(wrapperView, 7)
      nextAnimationFrame()
      expect(componentNode.offsetHeight).toBe lineHeightInPixels * 7

      setEditorWidthInChars(wrapperView, 10)
      expect(componentNode.querySelector('.scroll-view').offsetWidth).toBe charWidth * 10

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
      wrapperView.detach()
      wrapperView.attachToDom()

      wrapperView.trigger('core:move-right')

      expect(editor.getCursorBufferPosition()).toEqual [0, 1]

  describe 'scoped config settings', ->
    [coffeeEditor, coffeeComponent] = []

    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')
      waitsForPromise ->
        atom.project.open('coffee.coffee', autoIndent: false).then (o) -> coffeeEditor = o

    afterEach: ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe 'soft wrap settings', ->
      beforeEach ->
        atom.config.set 'editor.softWrap', true, scopeSelector: '.source.coffee'
        atom.config.set 'editor.preferredLineLength', 17, scopeSelector: '.source.coffee'
        atom.config.set 'editor.softWrapAtPreferredLineLength', true, scopeSelector: '.source.coffee'

        editor.setEditorWidthInChars(20)
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
        nextAnimationFrame()

      it "renders the invisibles when editor.showInvisibles is true for a given grammar", ->
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{jsInvisibles.space}a line with tabs#{jsInvisibles.tab}and spaces#{jsInvisibles.space}#{jsInvisibles.eol}"

      it "does not render the invisibles when editor.showInvisibles is false for a given grammar", ->
        editor.setGrammar(coffeeEditor.getGrammar())
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe " a line with tabs and spaces "

      it "re-renders the invisibles when the invisible settings change", ->
        jsGrammar = editor.getGrammar()
        editor.setGrammar(coffeeEditor.getGrammar())
        atom.config.set 'editor.showInvisibles', true, scopeSelector: '.source.coffee'
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{coffeeInvisibles.space}a line with tabs#{coffeeInvisibles.tab}and spaces#{coffeeInvisibles.space}#{coffeeInvisibles.eol}"

        newInvisibles =
          eol: 'N'
          space: 'E'
          tab: 'W'
          cr: 'I'
        atom.config.set 'editor.invisibles', newInvisibles, scopeSelector: '.source.coffee'
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{newInvisibles.space}a line with tabs#{newInvisibles.tab}and spaces#{newInvisibles.space}#{newInvisibles.eol}"

        editor.setGrammar(jsGrammar)
        nextAnimationFrame()
        expect(component.lineNodeForScreenRow(0).textContent).toBe "#{jsInvisibles.space}a line with tabs#{jsInvisibles.tab}and spaces#{jsInvisibles.space}#{jsInvisibles.eol}"

    describe 'editor.showIndentGuide', ->
      beforeEach ->
        atom.config.set 'editor.showIndentGuide', true, scopeSelector: '.source.js'
        atom.config.set 'editor.showIndentGuide', false, scopeSelector: '.source.coffee'
        nextAnimationFrame()

      it "has an 'indent-guide' class when scoped editor.showIndentGuide is true, but not when scoped editor.showIndentGuide is false", ->
        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

        editor.setGrammar(coffeeEditor.getGrammar())
        nextAnimationFrame()

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
        nextAnimationFrame()

        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe false
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

  describe "middle mouse paste on Linux", ->
    originalPlatform = null

    beforeEach ->
      originalPlatform = process.platform
      Object.defineProperty process, 'platform', value: 'linux'

    afterEach ->
      Object.defineProperty process, 'platform', value: originalPlatform

    it "pastes the previously selected text at the clicked location", ->
      jasmine.unspy(window, 'setTimeout')
      clipboardWrittenTo = false
      spyOn(require('ipc'), 'send').andCallFake (eventName, selectedText) ->
        if eventName is 'write-text-to-selection-clipboard'
          require('clipboard').writeText(selectedText, 'selection')
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
    clientX = scrollViewClientRect.left + positionOffset.left - editor.getScrollLeft()
    clientY = scrollViewClientRect.top + positionOffset.top - editor.getScrollTop()
    {clientX, clientY}

  clientCoordinatesForScreenRowInGutter = (screenRow) ->
    positionOffset = wrapperNode.pixelPositionForScreenPosition([screenRow, 1])
    gutterClientRect = componentNode.querySelector('.gutter').getBoundingClientRect()
    clientX = gutterClientRect.left + positionOffset.left - editor.getScrollLeft()
    clientY = gutterClientRect.top + positionOffset.top - editor.getScrollTop()
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
