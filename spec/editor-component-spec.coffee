React = require 'react'
{extend} = require 'underscore-plus'
EditorComponent = require '../src/editor-component'

describe "EditorComponent", ->
  [editor, component, node, lineHeightInPixels, charWidth, delayAnimationFrames, nextAnimationFrame] = []

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
      container = document.querySelector('#jasmine-content')
      component = React.renderComponent(EditorComponent({editor}), container)
      component.setLineHeight(1.3)
      component.setFontSize(20)
      {lineHeightInPixels, charWidth} = component.measureLineDimensions()
      node = component.getDOMNode()

  describe "scrolling", ->
    it "renders only the currently-visible lines", ->
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      lines = node.querySelectorAll('.line')
      expect(lines.length).toBe 5
      expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
      expect(lines[4].textContent).toBe editor.lineForScreenRow(4).text

      node.querySelector('.vertical-scrollbar').scrollTop = 2.5 * lineHeightInPixels
      component.onVerticalScroll()

      expect(node.querySelector('.scrollable-content').style['-webkit-transform']).toBe "translateY(#{-2.5 * lineHeightInPixels}px)"

      lines = node.querySelectorAll('.line')
      expect(lines.length).toBe 5
      expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
      expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text

      spacers = node.querySelectorAll('.spacer')
      expect(spacers[0].offsetHeight).toBe 2 * lineHeightInPixels
      expect(spacers[1].offsetHeight).toBe (editor.getScreenLineCount() - 7) * lineHeightInPixels

    it "updates the scroll bar when the scrollTop is changed in the model", ->
      node.style.height = 4.5 * lineHeightInPixels + 'px'
      component.updateAllDimensions()

      scrollbarNode = node.querySelector('.vertical-scrollbar')
      expect(scrollbarNode.scrollTop).toBe 0

      editor.setScrollTop(10)
      expect(scrollbarNode.scrollTop).toBe 10

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

  describe "selection rendering", ->
    it "renders 1 region for 1-line selections", ->
      # 1-line selection
      editor.setSelectedScreenRange([[1, 6], [1, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 1
      regionRect = regions[0].getBoundingClientRect()
      expect(regionRect.top).toBe 1 * lineHeightInPixels
      expect(regionRect.height).toBe 1 * lineHeightInPixels
      expect(regionRect.left).toBe 6 * charWidth
      expect(regionRect.width).toBe 4 * charWidth

    it "renders 2 regions for 2-line selections", ->
      editor.setSelectedScreenRange([[1, 6], [2, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 2

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe 6 * charWidth
      expect(region1Rect.right).toBe node.clientWidth

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 1 * lineHeightInPixels
      expect(region2Rect.left).toBe 0
      expect(region2Rect.width).toBe 10 * charWidth

    it "renders 3 regions for selections with more than 2 lines", ->
      editor.setSelectedScreenRange([[1, 6], [5, 10]])
      regions = node.querySelectorAll('.selection .region')
      expect(regions.length).toBe 3

      region1Rect = regions[0].getBoundingClientRect()
      expect(region1Rect.top).toBe 1 * lineHeightInPixels
      expect(region1Rect.height).toBe 1 * lineHeightInPixels
      expect(region1Rect.left).toBe 6 * charWidth
      expect(region1Rect.right).toBe node.clientWidth

      region2Rect = regions[1].getBoundingClientRect()
      expect(region2Rect.top).toBe 2 * lineHeightInPixels
      expect(region2Rect.height).toBe 3 * lineHeightInPixels
      expect(region2Rect.left).toBe 0
      expect(region2Rect.right).toBe node.clientWidth

      region3Rect = regions[2].getBoundingClientRect()
      expect(region3Rect.top).toBe 5 * lineHeightInPixels
      expect(region3Rect.height).toBe 1 * lineHeightInPixels
      expect(region3Rect.left).toBe 0
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
          component.updateAllDimensions()
          editor.setScrollTop(3.5 * lineHeightInPixels)

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
        expect(editor.getSelectedScreenRange()).toEqual [[5, 6], [5, 13]]

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), detail: 1))
        expect(editor.getSelectedScreenRange()).toEqual [[6, 6], [6, 6]]

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
      editorClientRect = node.getBoundingClientRect()
      clientX = editorClientRect.left + positionOffset.left
      clientY = editorClientRect.top + positionOffset.top - editor.getScrollTop()
      {clientX, clientY}

    buildMouseEvent = (type, properties...) ->
      properties = extend({bubbles: true, cancelable: true}, properties...)
      event = new MouseEvent(type, properties)
      Object.defineProperty(event, 'which', get: -> properties.which) if properties.which?
      event

  it "transfers focus to the hidden input", ->
    expect(document.activeElement).toBe document.body
    node.focus()
    expect(document.activeElement).toBe node.querySelector('.hidden-input')
