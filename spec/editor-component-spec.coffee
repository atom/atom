{extend, flatten, toArray} = require 'underscore-plus'
ReactEditorView = require '../src/react-editor-view'

describe "EditorComponent", ->
  [editor, wrapperView, component, node, lineHeightInPixels, charWidth, delayAnimationFrames, nextAnimationFrame] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    runs ->
      delayAnimationFrames = false
      nextAnimationFrame = null
      spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
        if delayAnimationFrames
          nextAnimationFrame = fn
        else
          fn()

      editor = atom.project.openSync('sample.js')
      wrapperView = new ReactEditorView(editor)
      wrapperView.attachToDom()
      {component} = wrapperView
      component.setLineHeight(1.3)
      component.setFontSize(20)
      {lineHeightInPixels, charWidth} = component.measureLineDimensions()
      node = component.getDOMNode()

  describe "line rendering", ->
    it "renders only the currently-visible lines", ->
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      lines = node.querySelectorAll('.line')
      expect(lines.length).toBe 6
      expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
      expect(lines[5].textContent).toBe editor.lineForScreenRow(5).text

      node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
      component.onVerticalScroll()

      expect(node.querySelector('.scroll-view-content').style['-webkit-transform']).toBe "translate(0px, #{-2.5 * lineHeightInPixels}px)"

      lines = node.querySelectorAll('.line')
      expect(lines.length).toBe 6
      expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
      expect(lines[5].textContent).toBe editor.lineForScreenRow(7).text

      spacers = node.querySelectorAll('.lines .spacer')
      expect(spacers[0].offsetHeight).toBe 2 * lineHeightInPixels
      expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 8) * lineHeightInPixels

    describe "when indent guides are enabled", ->
      beforeEach ->
        component.setShowIndentGuide(true)

      it "adds an 'indent-guide' class to spans comprising the leading whitespace", ->
        lines = node.querySelectorAll('.line')
        line1LeafNodes = getLeafNodes(lines[1])
        expect(line1LeafNodes[0].textContent).toBe '  '
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe false

        line2LeafNodes = getLeafNodes(lines[2])
        expect(line2LeafNodes[0].textContent).toBe '  '
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[1].textContent).toBe '  '
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe false

      it "renders leading whitespace spans with the 'indent-guide' class for empty lines", ->
        editor.getBuffer().insert([1, Infinity], '\n')

        lines = node.querySelectorAll('.line')
        line2LeafNodes = getLeafNodes(lines[2])

        expect(line2LeafNodes.length).toBe 3
        expect(line2LeafNodes[0].textContent).toBe '  '
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[1].textContent).toBe '  '
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[2].textContent).toBe '  '
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe true

      it "renders indent guides correctly on lines containing only whitespace", ->
        editor.getBuffer().insert([1, Infinity], '\n      ')
        lines = node.querySelectorAll('.line')
        line2LeafNodes = getLeafNodes(lines[2])
        expect(line2LeafNodes.length).toBe 3
        expect(line2LeafNodes[0].textContent).toBe '  '
        expect(line2LeafNodes[0].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[1].textContent).toBe '  '
        expect(line2LeafNodes[1].classList.contains('indent-guide')).toBe true
        expect(line2LeafNodes[2].textContent).toBe '  '
        expect(line2LeafNodes[2].classList.contains('indent-guide')).toBe true

      getLeafNodes = (node) ->
        if node.children.length > 0
          flatten(toArray(node.children).map(getLeafNodes))
        else
          [node]

  describe "gutter rendering", ->
    nbsp = String.fromCharCode(160)

    it "renders the currently-visible line numbers", ->
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      lines = node.querySelectorAll('.line-number')
      expect(lines.length).toBe 6
      expect(lines[0].textContent).toBe "#{nbsp}1"
      expect(lines[5].textContent).toBe "#{nbsp}6"

      node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
      component.onVerticalScroll()

      expect(node.querySelector('.line-numbers').style['-webkit-transform']).toBe "translateY(#{-2.5 * lineHeightInPixels}px)"

      lines = node.querySelectorAll('.line-number')
      expect(lines.length).toBe 6
      expect(lines[0].textContent).toBe "#{nbsp}3"
      expect(lines[5].textContent).toBe "#{nbsp}8"

      spacers = node.querySelectorAll('.line-numbers .spacer')
      expect(spacers[0].offsetHeight).toBe 2 * lineHeightInPixels
      expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 8) * lineHeightInPixels

    it "renders • characters for soft-wrapped lines", ->
      editor.setSoftWrap(true)
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      node.style.width = 30 * charWidth + 'px'
      component.updateAllDimensions()

      lines = node.querySelectorAll('.line-number')
      expect(lines.length).toBe 6
      expect(lines[0].textContent).toBe "#{nbsp}1"
      expect(lines[1].textContent).toBe "#{nbsp}•"
      expect(lines[2].textContent).toBe "#{nbsp}2"
      expect(lines[3].textContent).toBe "#{nbsp}•"
      expect(lines[4].textContent).toBe "#{nbsp}3"
      expect(lines[5].textContent).toBe "#{nbsp}•"

  describe "cursor rendering", ->
    it "renders the currently visible cursors", ->
      cursor1 = editor.getCursor()
      cursor1.setScreenPosition([0, 5])

      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      cursorNodes = node.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 1
      expect(cursorNodes[0].offsetHeight).toBe lineHeightInPixels
      expect(cursorNodes[0].offsetWidth).toBe charWidth
      expect(cursorNodes[0].offsetTop).toBe 0
      expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth

      cursor2 = editor.addCursorAtScreenPosition([6, 11])
      cursor3 = editor.addCursorAtScreenPosition([4, 10])

      cursorNodes = node.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 2
      expect(cursorNodes[0].offsetTop).toBe 0
      expect(cursorNodes[0].offsetLeft).toBe 5 * charWidth
      expect(cursorNodes[1].offsetTop).toBe 4 * lineHeightInPixels
      expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

      node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
      component.onVerticalScroll()

      cursorNodes = node.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 2
      expect(cursorNodes[0].offsetTop).toBe 6 * lineHeightInPixels
      expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth
      expect(cursorNodes[1].offsetTop).toBe 4 * lineHeightInPixels
      expect(cursorNodes[1].offsetLeft).toBe 10 * charWidth

      cursor3.destroy()
      cursorNodes = node.querySelectorAll('.cursor')
      expect(cursorNodes.length).toBe 1
      expect(cursorNodes[0].offsetTop).toBe 6 * lineHeightInPixels
      expect(cursorNodes[0].offsetLeft).toBe 11 * charWidth

    it "accounts for character widths when positioning cursors", ->
      atom.config.set('editor.fontFamily', 'sans-serif')
      editor.setCursorScreenPosition([0, 16])

      cursor = node.querySelector('.cursor')
      cursorRect = cursor.getBoundingClientRect()

      cursorLocationTextNode = node.querySelector('.storage.type.function.js').firstChild.firstChild
      range = document.createRange()
      range.setStart(cursorLocationTextNode, 0)
      range.setEnd(cursorLocationTextNode, 1)
      rangeRect = range.getBoundingClientRect()

      expect(cursorRect.left).toBe rangeRect.left
      expect(cursorRect.width).toBe rangeRect.width

    it "blinks cursors when they aren't moving", ->
      editor.addCursorAtScreenPosition([1, 0])
      [cursorNode1, cursorNode2] = node.querySelectorAll('.cursor')
      expect(cursorNode1.classList.contains('blink-off')).toBe false
      expect(cursorNode2.classList.contains('blink-off')).toBe false

      advanceClock(component.props.cursorBlinkPeriod / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe true
      expect(cursorNode2.classList.contains('blink-off')).toBe true

      advanceClock(component.props.cursorBlinkPeriod / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe false
      expect(cursorNode2.classList.contains('blink-off')).toBe false

      advanceClock(component.props.cursorBlinkPeriod / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe true
      expect(cursorNode2.classList.contains('blink-off')).toBe true

      # Stop blinking immediately when cursors move
      advanceClock(component.props.cursorBlinkPeriod / 4)
      expect(cursorNode1.classList.contains('blink-off')).toBe true
      expect(cursorNode2.classList.contains('blink-off')).toBe true

      # Stop blinking for one full period after moving the cursor
      editor.moveCursorRight()
      expect(cursorNode1.classList.contains('blink-off')).toBe false
      expect(cursorNode2.classList.contains('blink-off')).toBe false

      advanceClock(component.props.cursorBlinkResumeDelay / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe false
      expect(cursorNode2.classList.contains('blink-off')).toBe false

      advanceClock(component.props.cursorBlinkResumeDelay / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe true
      expect(cursorNode2.classList.contains('blink-off')).toBe true

      advanceClock(component.props.cursorBlinkPeriod / 2)
      expect(cursorNode1.classList.contains('blink-off')).toBe false
      expect(cursorNode2.classList.contains('blink-off')).toBe false

    it "renders the hidden input field at the position of the last cursor if it is on screen", ->
      inputNode = node.querySelector('.hidden-input')
      node.style.height = 5 * lineHeightInPixels + 'px'
      node.style.width = 10 * charWidth + 'px'
      component.updateAllDimensions()

      expect(editor.getCursorScreenPosition()).toEqual [0, 0]
      editor.setScrollTop(3 * lineHeightInPixels)
      editor.setScrollLeft(3 * charWidth)
      expect(inputNode.offsetTop).toBe 0
      expect(inputNode.offsetLeft).toBe 0

      editor.setCursorBufferPosition([5, 5])
      cursorRect = editor.getCursor().getPixelRect()
      cursorTop = cursorRect.top
      cursorLeft = cursorRect.left
      expect(inputNode.offsetTop).toBe cursorTop - editor.getScrollTop()
      expect(inputNode.offsetLeft).toBe cursorLeft - editor.getScrollLeft()

  describe "selection rendering", ->
    scrollViewClientLeft = null

    beforeEach ->
      scrollViewClientLeft = node.querySelector('.scroll-view').getBoundingClientRect().left

    it "renders 1 region for 1-line selections", ->
      # 1-line selection
      editor.setSelectedScreenRange([[1, 6], [1, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 1
      regionRect = regions[0].getBoundingClientRect()
      expect(regionRect.top).toBe 1 * lineHeightInPixels
      expect(regionRect.height).toBe 1 * lineHeightInPixels
      expect(regionRect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(regionRect.width).toBe 4 * charWidth

    it "renders 2 regions for 2-line selections", ->
      editor.setSelectedScreenRange([[1, 6], [2, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 2

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(region1Rect.right).toBe node.clientWidth

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 1 * lineHeightInPixels
      expect(region2Rect.left).toBe scrollViewClientLeft + 0
      expect(region2Rect.width).toBe 10 * charWidth

    it "renders 3 regions for selections with more than 2 lines", ->
      editor.setSelectedScreenRange([[1, 6], [5, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 3

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe scrollViewClientLeft + 6 * charWidth
      expect(region1Rect.right).toBe node.clientWidth

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 3 * lineHeightInPixels
      expect(region2Rect.left).toBe scrollViewClientLeft + 0
      expect(region2Rect.right).toBe node.clientWidth

      region3Rect = regions[2].getBoundingClientRect()
      expect(region3Rect.top).toBe 5 * lineHeightInPixels
      expect(region3Rect.height).toBe 1 * lineHeightInPixels
      expect(region3Rect.left).toBe scrollViewClientLeft + 0
      expect(region3Rect.width).toBe 10 * charWidth

  describe "mouse interactions", ->
    linesNode = null

    beforeEach ->
      delayAnimationFrames = true
      linesNode = node.querySelector('.lines')

    describe "when a non-folded line is single-clicked", ->
      describe "when no modifier keys are held down", ->
        it "moves the cursor to the nearest screen position", ->
          node.style.height = 4.5 * lineHeightInPixels + 'px'
          node.style.width = 10 * charWidth + 'px'
          component.updateAllDimensions()
          editor.setScrollTop(3.5 * lineHeightInPixels)
          editor.setScrollLeft(2 * charWidth)

          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8])))
          expect(editor.getCursorScreenPosition()).toEqual [4, 8]

      describe "when the shift key is held down", ->
        it "selects to the nearest screen position", ->
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), shiftKey: true))
          expect(editor.getSelectedScreenRange()).toEqual [[3, 4], [5, 6]]

      describe "when the command key is held down", ->
        it "adds a cursor at the nearest screen position", ->
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), metaKey: true))
          expect(editor.getSelectedScreenRanges()).toEqual [[[3, 4], [3, 4]], [[5, 6], [5, 6]]]

    describe "when a non-folded line is double-clicked", ->
      it "selects the word containing the nearest screen position", ->
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), detail: 2))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [5, 13]]

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), detail: 1))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        expect(editor.getSelectedScreenRange()).toEqual [[6, 6], [6, 6]]

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), detail: 1, shiftKey: true))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        expect(editor.getSelectedScreenRange()).toEqual [[6, 6], [8, 8]]

    describe "when a non-folded line is triple-clicked", ->
      it "selects the line containing the nearest screen position", ->
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
        nextAnimationFrame()
        expect(editor.getSelectedScreenRange()).toEqual [[2, 4], [6, 8]]

    clientCoordinatesForScreenPosition = (screenPosition) ->
      positionOffset = editor.pixelPositionForScreenPosition(screenPosition)
      scrollViewClientRect = node.querySelector('.scroll-view').getBoundingClientRect()
      clientX = scrollViewClientRect.left + positionOffset.left - editor.getScrollLeft()
      clientY = scrollViewClientRect.top + positionOffset.top - editor.getScrollTop()
      {clientX, clientY}

    buildMouseEvent = (type, properties...) ->
      properties = extend({bubbles: true, cancelable: true}, properties...)
      event = new MouseEvent(type, properties)
      Object.defineProperty(event, 'which', get: -> properties.which) if properties.which?
      event

  describe "focus handling", ->
    inputNode = null

    beforeEach ->
      inputNode = node.querySelector('.hidden-input')

    it "transfers focus to the hidden input", ->
      expect(document.activeElement).toBe document.body
      node.focus()
      expect(document.activeElement).toBe inputNode

    it "adds the 'is-focused' class to the editor when the hidden input is focused", ->
      expect(document.activeElement).toBe document.body
      inputNode.focus()
      expect(node.classList.contains('is-focused')).toBe true
      inputNode.blur()
      expect(node.classList.contains('is-focused')).toBe false

  describe "scrolling", ->
    it "updates the vertical scrollbar when the scrollTop is changed in the model", ->
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      scrollbarNode = node.querySelector('.vertical-scrollbar')
      expect(scrollbarNode.scrollTop).toBe 0

      editor.setScrollTop(10)
      expect(scrollbarNode.scrollTop).toBe 10

    it "updates the horizontal scrollbar and scroll view content x transform based on the scrollLeft of the model", ->
      node.style.width = 30 * charWidth + 'px'
      component.updateAllDimensions()

      scrollViewContentNode = node.querySelector('.scroll-view-content')
      horizontalScrollbarNode = node.querySelector('.horizontal-scrollbar')
      expect(scrollViewContentNode.style['-webkit-transform']).toBe "translate(0px, 0px)"
      expect(horizontalScrollbarNode.scrollLeft).toBe 0

      editor.setScrollLeft(100)
      expect(scrollViewContentNode.style['-webkit-transform']).toBe "translate(-100px, 0px)"
      expect(horizontalScrollbarNode.scrollLeft).toBe 100

    it "updates the scrollLeft of the model when the scrollLeft of the horizontal scrollbar changes", ->
      node.style.width = 30 * charWidth + 'px'
      component.updateAllDimensions()

      expect(editor.getScrollLeft()).toBe 0
      node.querySelector('.horizontal-scrollbar').scrollLeft = 100
      component.onHorizontalScroll()

      expect(editor.getScrollLeft()).toBe 100

    describe "when a mousewheel event occurs on the editor", ->
      it "updates the horizontal or vertical scrollbar depending on which delta is greater (x or y)", ->
        node.style.height = 4.5 * lineHeightInPixels + 'px'
        node.style.width = 20 * charWidth + 'px'
        component.updateAllDimensions()

        verticalScrollbarNode = node.querySelector('.vertical-scrollbar')
        horizontalScrollbarNode = node.querySelector('.horizontal-scrollbar')

        expect(verticalScrollbarNode.scrollTop).toBe 0
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        node.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -5, wheelDeltaY: -10))
        expect(verticalScrollbarNode.scrollTop).toBe 10
        expect(horizontalScrollbarNode.scrollLeft).toBe 0

        node.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -15, wheelDeltaY: -5))
        expect(verticalScrollbarNode.scrollTop).toBe 10
        expect(horizontalScrollbarNode.scrollLeft).toBe 15

  describe "input events", ->
    it "inserts the typed character into the buffer", ->
      component.onInput('x')
      expect(editor.lineForBufferRow(0)).toBe 'xvar quicksort = function () {'

    it "replaces the last character if replaceLastCharacter is true", ->
      component.onInput('u')
      component.onInput('ü', true)
      expect(editor.lineForBufferRow(0)).toBe 'üvar quicksort = function () {'
