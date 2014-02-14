WorkspaceView = require '../src/workspace-view'
EditorView = require '../src/editor-view'
{$, $$} = require '../src/space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
temp = require 'temp'

describe "EditorView", ->
  [buffer, editorView, editor, cachedLineHeight, cachedCharWidth] = []

  beforeEach ->
    editor = atom.project.openSync('sample.js')
    buffer = editor.buffer
    editorView = new EditorView(editor)
    editorView.lineOverdraw = 2
    editorView.isFocused = true
    editorView.enableKeymap()
    editorView.calculateHeightInLines = ->
      Math.ceil(@height() / @lineHeight)
    editorView.attachToDom = ({ heightInLines, widthInChars } = {}) ->
      heightInLines ?= @getEditor().getBuffer().getLineCount()
      @height(getLineHeight() * heightInLines)
      @width(getCharWidth() * widthInChars) if widthInChars
      $('#jasmine-content').append(this)

    waitsForPromise ->
      atom.packages.activatePackage('language-text', sync: true)

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript', sync: true)

  getLineHeight = ->
    return cachedLineHeight if cachedLineHeight?
    calcDimensions()
    cachedLineHeight

  getCharWidth = ->
    return cachedCharWidth if cachedCharWidth?
    calcDimensions()
    cachedCharWidth

  calcDimensions = ->
    editorForMeasurement = new EditorView(editor: atom.project.openSync('sample.js'))
    editorForMeasurement.attachToDom()
    cachedLineHeight = editorForMeasurement.lineHeight
    cachedCharWidth = editorForMeasurement.charWidth
    editorForMeasurement.remove()

  describe "construction", ->
    it "throws an error if no edit session is given", ->
      expect(-> new EditorView).toThrow()

  describe "when the editor view view is attached to the dom", ->
    it "calculates line height and char width and updates the pixel position of the cursor", ->
      expect(editorView.lineHeight).toBeNull()
      expect(editorView.charWidth).toBeNull()
      editor.setCursorScreenPosition(row: 2, column: 2)

      editorView.attachToDom()

      expect(editorView.lineHeight).not.toBeNull()
      expect(editorView.charWidth).not.toBeNull()
      expect(editorView.find('.cursor').offset()).toEqual pagePixelPositionForPoint(editorView, [2, 2])

    it "is focused", ->
      editorView.attachToDom()
      expect(editorView).toMatchSelector ":has(:focus)"

  describe "when the editor view view receives focus", ->
    it "focuses the hidden input", ->
      editorView.attachToDom()
      editorView.focus()
      expect(editorView).not.toMatchSelector ':focus'
      expect(editorView.hiddenInput).toMatchSelector ':focus'

    it "does not scroll the editor view (regression)", ->
      editorView.attachToDom(heightInLines: 2)
      editor.selectAll()
      editorView.hiddenInput.blur()
      editorView.focus()

      expect(editorView.hiddenInput).toMatchSelector ':focus'
      expect($(editorView[0]).scrollTop()).toBe 0
      expect($(editorView.scrollView[0]).scrollTop()).toBe 0

      editor.moveCursorToBottom()
      editorView.hiddenInput.blur()
      editorView.scrollTop(0)
      editorView.focus()

      expect(editorView.hiddenInput).toMatchSelector ':focus'
      expect($(editorView[0]).scrollTop()).toBe 0
      expect($(editorView.scrollView[0]).scrollTop()).toBe 0

  describe "when the hidden input is focused / unfocused", ->
    it "assigns the isFocused flag on the editor view view and also adds/removes the .focused css class", ->
      editorView.attachToDom()
      editorView.isFocused = false
      editorView.hiddenInput.focus()
      expect(editorView.isFocused).toBeTruthy()

      editorView.hiddenInput.focusout()
      expect(editorView.isFocused).toBeFalsy()

  describe "when the editor's file is modified on disk", ->
    it "triggers an alert", ->
      filePath = path.join(temp.dir, 'atom-changed-file.txt')
      fs.writeFileSync(filePath, "")
      editor = atom.project.openSync(filePath)
      editorView.edit(editor)
      editor.insertText("now the buffer is modified")

      fileChangeHandler = jasmine.createSpy('fileChange')
      editor.buffer.file.on 'contents-changed', fileChangeHandler

      spyOn(atom, "confirm")

      fs.writeFileSync(filePath, "a file change")

      waitsFor "file to trigger contents-changed event", ->
        fileChangeHandler.callCount > 0

      runs ->
        expect(atom.confirm).toHaveBeenCalled()

  describe ".remove()", ->
    it "destroys the edit session", ->
      editorView.remove()
      expect(editorView.editor.isDestroyed()).toBe true

  describe ".edit(editor)", ->
    [newEditor, newBuffer] = []

    beforeEach ->
      newEditor = atom.project.openSync('two-hundred.txt')
      newBuffer = newEditor.buffer

    it "updates the rendered lines, cursors, selections, scroll position, and event subscriptions to match the given edit session", ->
      editorView.attachToDom(heightInLines: 5, widthInChars: 30)
      editor.setCursorBufferPosition([6, 13])
      editorView.scrollToBottom()
      editorView.scrollLeft(150)
      previousScrollHeight = editorView.verticalScrollbar.prop('scrollHeight')
      previousScrollTop = editorView.scrollTop()
      previousScrollLeft = editorView.scrollLeft()

      newEditor.setScrollTop(900)
      newEditor.setSelectedBufferRange([[40, 0], [43, 1]])

      editorView.edit(newEditor)
      { firstRenderedScreenRow, lastRenderedScreenRow } = editorView
      expect(editorView.lineElementForScreenRow(firstRenderedScreenRow).text()).toBe newBuffer.lineForRow(firstRenderedScreenRow)
      expect(editorView.lineElementForScreenRow(lastRenderedScreenRow).text()).toBe newBuffer.lineForRow(editorView.lastRenderedScreenRow)
      expect(editorView.scrollTop()).toBe 900
      expect(editorView.scrollLeft()).toBe 0
      expect(editorView.getSelectionView().regions[0].position().top).toBe 40 * editorView.lineHeight
      newEditor.insertText("hello")
      expect(editorView.lineElementForScreenRow(40).text()).toBe "hello3"

      editorView.edit(editor)
      { firstRenderedScreenRow, lastRenderedScreenRow } = editorView
      expect(editorView.lineElementForScreenRow(firstRenderedScreenRow).text()).toBe buffer.lineForRow(firstRenderedScreenRow)
      expect(editorView.lineElementForScreenRow(lastRenderedScreenRow).text()).toBe buffer.lineForRow(editorView.lastRenderedScreenRow)
      expect(editorView.verticalScrollbar.prop('scrollHeight')).toBe previousScrollHeight
      expect(editorView.scrollTop()).toBe previousScrollTop
      expect(editorView.scrollLeft()).toBe previousScrollLeft
      expect(editorView.getCursorView().position()).toEqual { top: 6 * editorView.lineHeight, left: 13 * editorView.charWidth }
      editor.insertText("goodbye")
      expect(editorView.lineElementForScreenRow(6).text()).toMatch /^      currentgoodbye/

    it "triggers alert if edit session's buffer goes into conflict with changes on disk", ->
      filePath = path.join(temp.dir, 'atom-changed-file.txt')
      fs.writeFileSync(filePath, "")
      tempEditor = atom.project.openSync(filePath)
      editorView.edit(tempEditor)
      tempEditor.insertText("a buffer change")

      spyOn(atom, "confirm")

      contentsConflictedHandler = jasmine.createSpy("contentsConflictedHandler")
      tempEditor.on 'contents-conflicted', contentsConflictedHandler
      fs.writeFileSync(filePath, "a file change")
      waitsFor ->
        contentsConflictedHandler.callCount > 0

      runs ->
        expect(atom.confirm).toHaveBeenCalled()

  describe ".scrollTop(n)", ->
    beforeEach ->
      editorView.attachToDom(heightInLines: 5)
      expect(editorView.verticalScrollbar.scrollTop()).toBe 0

    describe "when called with a scroll top argument", ->
      it "sets the scrollTop of the vertical scrollbar and sets scrollTop on the line numbers and lines", ->
        editorView.scrollTop(100)
        expect(editorView.verticalScrollbar.scrollTop()).toBe 100
        expect(editorView.scrollView.scrollTop()).toBe 0
        expect(editorView.renderedLines.css('top')).toBe "-100px"
        expect(editorView.gutter.lineNumbers.css('top')).toBe "-100px"

        editorView.scrollTop(120)
        expect(editorView.verticalScrollbar.scrollTop()).toBe 120
        expect(editorView.scrollView.scrollTop()).toBe 0
        expect(editorView.renderedLines.css('top')).toBe "-120px"
        expect(editorView.gutter.lineNumbers.css('top')).toBe "-120px"

      it "does not allow negative scrollTops to be assigned", ->
        editorView.scrollTop(-100)
        expect(editorView.scrollTop()).toBe 0

      it "doesn't do anything if the scrollTop hasn't changed", ->
        editorView.scrollTop(100)
        spyOn(editorView.verticalScrollbar, 'scrollTop')
        spyOn(editorView.renderedLines, 'css')
        spyOn(editorView.gutter.lineNumbers, 'css')

        editorView.scrollTop(100)
        expect(editorView.verticalScrollbar.scrollTop).not.toHaveBeenCalled()
        expect(editorView.renderedLines.css).not.toHaveBeenCalled()
        expect(editorView.gutter.lineNumbers.css).not.toHaveBeenCalled()

      describe "when the 'adjustVerticalScrollbar' option is false (defaults to true)", ->
        it "doesn't adjust the scrollTop of the vertical scrollbar", ->
          editorView.scrollTop(100, adjustVerticalScrollbar: false)
          expect(editorView.verticalScrollbar.scrollTop()).toBe 0
          expect(editorView.renderedLines.css('top')).toBe "-100px"
          expect(editorView.gutter.lineNumbers.css('top')).toBe "-100px"

    describe "when called with no argument", ->
      it "returns the last assigned value or 0 if none has been assigned", ->
        expect(editorView.scrollTop()).toBe 0
        editorView.scrollTop(50)
        expect(editorView.scrollTop()).toBe 50

    it "sets the new scroll top position on the active edit session", ->
      expect(editorView.editor.getScrollTop()).toBe 0
      editorView.scrollTop(123)
      expect(editorView.editor.getScrollTop()).toBe 123

  describe ".scrollHorizontally(pixelPosition)", ->
    it "sets the new scroll left position on the active edit session", ->
      editorView.attachToDom(heightInLines: 5)
      setEditorWidthInChars(editorView, 5)
      expect(editorView.editor.getScrollLeft()).toBe 0
      editorView.scrollHorizontally(left: 50)
      expect(editorView.editor.getScrollLeft()).toBeGreaterThan 0
      expect(editorView.editor.getScrollLeft()).toBe editorView.scrollLeft()

  describe "editor:attached event", ->
    it 'only triggers an editor:attached event when it is first added to the DOM', ->
      openHandler = jasmine.createSpy('openHandler')
      editorView.on 'editor:attached', openHandler

      editorView.attachToDom()
      expect(openHandler).toHaveBeenCalled()
      [event, eventEditor] = openHandler.argsForCall[0]
      expect(eventEditor).toBe editorView

      openHandler.reset()
      editorView.attachToDom()
      expect(openHandler).not.toHaveBeenCalled()

  describe "editor:path-changed event", ->
    filePath = null

    beforeEach ->
      filePath = path.join(temp.dir, 'something.txt')
      fs.writeFileSync(filePath, filePath)

    afterEach ->
      fs.removeSync(filePath) if fs.existsSync(filePath)

    it "emits event when buffer's path is changed", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editorView.on 'editor:path-changed', eventHandler
      editor.saveAs(filePath)
      expect(eventHandler).toHaveBeenCalled()

    it "emits event when editor view view receives a new buffer", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editorView.on 'editor:path-changed', eventHandler
      editorView.edit(atom.project.openSync(filePath))
      expect(eventHandler).toHaveBeenCalled()

    it "stops listening to events on previously set buffers", ->
      eventHandler = jasmine.createSpy('eventHandler')
      oldBuffer = editor.getBuffer()
      newEditor = atom.project.openSync(filePath)
      editorView.on 'editor:path-changed', eventHandler


      editorView.edit(newEditor)
      expect(eventHandler).toHaveBeenCalled()

      eventHandler.reset()
      oldBuffer.saveAs(path.join(temp.dir, 'atom-bad.txt'))
      expect(eventHandler).not.toHaveBeenCalled()

      eventHandler.reset()
      newEditor.getBuffer().saveAs(path.join(temp.dir, 'atom-new.txt'))
      expect(eventHandler).toHaveBeenCalled()

    it "loads the grammar for the new path", ->
      expect(editor.getGrammar().name).toBe 'JavaScript'
      editor.getBuffer().saveAs(filePath)
      expect(editor.getGrammar().name).toBe 'Plain Text'

  describe "font family", ->
    beforeEach ->
      expect(editorView.css('font-family')).toBe 'Courier'

    it "when there is no config in fontFamily don't set it", ->
      atom.config.set('editor.fontFamily', null)
      expect(editorView.css('font-family')).toBe ''

    describe "when the font family changes", ->
      [fontFamily] = []

      beforeEach ->
        if process.platform is 'darwin'
          fontFamily = "PCMyungjo"
        else
          fontFamily = "Consolas"

      it "updates the font family of editors and recalculates dimensions critical to cursor positioning", ->
        editorView.attachToDom(12)
        lineHeightBefore = editorView.lineHeight
        charWidthBefore = editorView.charWidth
        editor.setCursorScreenPosition [5, 6]

        atom.config.set("editor.fontFamily", fontFamily)
        expect(editorView.css('font-family')).toBe fontFamily
        expect(editorView.charWidth).not.toBe charWidthBefore
        expect(editorView.getCursorView().position()).toEqual { top: 5 * editorView.lineHeight, left: 6 * editorView.charWidth }

        newEditor = new EditorView(editorView.editor.copy())
        newEditor.attachToDom()
        expect(newEditor.css('font-family')).toBe fontFamily

  describe "font size", ->
    beforeEach ->
      expect(editorView.css('font-size')).not.toBe "20px"
      expect(editorView.css('font-size')).not.toBe "10px"

    it "sets the initial font size based on the value from config", ->
      expect(editorView.css('font-size')).toBe "#{atom.config.get('editor.fontSize')}px"

    describe "when the font size changes", ->
      it "updates the font sizes of editors and recalculates dimensions critical to cursor positioning", ->
        atom.config.set("editor.fontSize", 10)
        editorView.attachToDom()
        lineHeightBefore = editorView.lineHeight
        charWidthBefore = editorView.charWidth
        editor.setCursorScreenPosition [5, 6]

        atom.config.set("editor.fontSize", 30)
        expect(editorView.css('font-size')).toBe '30px'
        expect(editorView.lineHeight).toBeGreaterThan lineHeightBefore
        expect(editorView.charWidth).toBeGreaterThan charWidthBefore
        expect(editorView.getCursorView().position()).toEqual { top: 5 * editorView.lineHeight, left: 6 * editorView.charWidth }
        expect(editorView.renderedLines.outerHeight()).toBe buffer.getLineCount() * editorView.lineHeight
        expect(editorView.verticalScrollbarContent.height()).toBe buffer.getLineCount() * editorView.lineHeight

        newEditor = new EditorView(editorView.editor.copy())
        editorView.remove()
        newEditor.attachToDom()
        expect(newEditor.css('font-size')).toBe '30px'

      it "updates the position and size of selection regions", ->
        atom.config.set("editor.fontSize", 10)
        editor.setSelectedBufferRange([[5, 2], [5, 7]])
        editorView.attachToDom()

        atom.config.set("editor.fontSize", 30)
        selectionRegion = editorView.find('.region')
        expect(selectionRegion.position().top).toBe 5 * editorView.lineHeight
        expect(selectionRegion.position().left).toBe 2 * editorView.charWidth
        expect(selectionRegion.height()).toBe editorView.lineHeight
        expect(selectionRegion.width()).toBe 5 * editorView.charWidth

      it "updates lines if there are unrendered lines", ->
        editorView.attachToDom(heightInLines: 5)
        originalLineCount = editorView.renderedLines.find(".line").length
        expect(originalLineCount).toBeGreaterThan 0

        atom.config.set("editor.fontSize", 10)
        expect(editorView.renderedLines.find(".line").length).toBeGreaterThan originalLineCount

      describe "when the font size changes while editor view view is detached", ->
        it "redraws the editor view view according to the new font size when it is reattached", ->
          editor.setCursorScreenPosition([4, 2])
          editorView.attachToDom()
          initialLineHeight = editorView.lineHeight
          initialCharWidth = editorView.charWidth
          initialCursorPosition = editorView.getCursorView().position()
          initialScrollbarHeight = editorView.verticalScrollbarContent.height()
          editorView.detach()

          atom.config.set("editor.fontSize", 10)
          expect(editorView.lineHeight).toBe initialLineHeight
          expect(editorView.charWidth).toBe initialCharWidth

          editorView.attachToDom()
          expect(editorView.lineHeight).not.toBe initialLineHeight
          expect(editorView.charWidth).not.toBe initialCharWidth
          expect(editorView.getCursorView().position()).not.toEqual initialCursorPosition
          expect(editorView.verticalScrollbarContent.height()).not.toBe initialScrollbarHeight

  describe "mouse events", ->
    beforeEach ->
      editorView.attachToDom()
      editorView.css(position: 'absolute', top: 10, left: 10, width: 400)

    describe "single-click", ->
      it "re-positions the cursor to the clicked row / column", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 10])
        expect(editor.getCursorScreenPosition()).toEqual(row: 3, column: 10)

      describe "when the lines are scrolled to the right", ->
        it "re-positions the cursor on the clicked location", ->
          setEditorWidthInChars(editorView, 30)
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 30]) # scrolls lines to the right
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 50])
          expect(editor.getCursorBufferPosition()).toEqual(row: 3, column: 50)

      describe "when the editor view view is using a variable-width font", ->
        beforeEach ->
          editorView.setFontFamily('sans-serif')

      it "positions the cursor to the clicked row and column", ->
          {top, left} = editorView.pixelOffsetForScreenPosition([3, 30])
          editorView.renderedLines.trigger mousedownEvent(pageX: left, pageY: top)
          expect(editor.getCursorScreenPosition()).toEqual [3, 30]

    describe "double-click", ->
      it "selects the word under the cursor, and expands the selection wordwise in either direction on a subsequent shift-click", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [8, 24], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [8, 24], originalEvent: {detail: 2})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "concat"

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [8, 7], shiftKey: true)
        editorView.renderedLines.trigger 'mouseup'

        expect(editor.getSelectedText()).toBe "return sort(left).concat"

      it "stops selecting by word when the selection is emptied", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 8], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 8], originalEvent: {detail: 2})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "quicksort"

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 10])
        editorView.renderedLines.trigger 'mouseup'

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 12], originalEvent: {detail: 1}, shiftKey: true)
        expect(editor.getSelectedBufferRange()).toEqual [[3, 10], [3, 12]]

      describe "when clicking between a word and a non-word", ->
        it "selects the word", ->
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 21], originalEvent: {detail: 1})
          editorView.renderedLines.trigger 'mouseup'
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 21], originalEvent: {detail: 2})
          editorView.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "function"

          editor.setCursorBufferPosition([0, 0])
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 22], originalEvent: {detail: 1})
          editorView.renderedLines.trigger 'mouseup'
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 22], originalEvent: {detail: 2})
          editorView.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "items"

          editor.setCursorBufferPosition([0, 0])
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 28], originalEvent: {detail: 1})
          editorView.renderedLines.trigger 'mouseup'
          editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 28], originalEvent: {detail: 2})
          editorView.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "{"

    describe "triple/quardruple/etc-click", ->
      it "selects the line under the cursor", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

        # Triple click
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 8], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 8], originalEvent: {detail: 2})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 8], originalEvent: {detail: 3})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "  var sort = function(items) {\n"

        # Quad click
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [2, 3], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [2, 3], originalEvent: {detail: 2})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [2, 3], originalEvent: {detail: 3})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [2, 3], originalEvent: {detail: 4})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "    if (items.length <= 1) return items;\n"

      it "expands the selection linewise in either direction on a subsequent shift-click, but stops selecting linewise once the selection is emptied", ->
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 8], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 8], originalEvent: {detail: 2})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 8], originalEvent: {detail: 3})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [5, 0]]

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [1, 8], originalEvent: {detail: 1}, shiftKey: true)
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [5, 0]]

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [2, 8], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().isEmpty()).toBeTruthy()

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [3, 8], originalEvent: {detail: 1}, shiftKey: true)
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [3, 8]]

    describe "shift-click", ->
      it "selects from the cursor's current location to the clicked location", ->
        editor.setCursorScreenPosition([4, 7])
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true)
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "shift-double-click", ->
      it "expands the selection on the first click and ignores the second click", ->
        editor.setCursorScreenPosition([4, 7])
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "shift-triple-click", ->
      it "expands the selection on the first click and ignores the second click", ->
        editor.setCursorScreenPosition([4, 7])
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 24], shiftKey: true, originalEvent: { detail: 3 })
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "meta-click", ->
      it "places an additional cursor", ->
        editorView.attachToDom()
        setEditorHeightInLines(editorView, 5)
        editor.setCursorBufferPosition([3, 0])
        editorView.scrollTop(editorView.lineHeight * 6)

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [6, 0], metaKey: true)
        expect(editorView.scrollTop()).toBe editorView.lineHeight * (6 - editorView.vScrollMargin)

        [cursor1, cursor2] = editorView.getCursorViews()
        expect(cursor1.position()).toEqual(top: 3 * editorView.lineHeight, left: 0)
        expect(cursor1.getBufferPosition()).toEqual [3, 0]
        expect(cursor2.position()).toEqual(top: 6 * editorView.lineHeight, left: 0)
        expect(cursor2.getBufferPosition()).toEqual [6, 0]

    describe "click and drag", ->
      it "creates a selection from the initial click to mouse cursor's location ", ->
        editorView.attachToDom()
        editorView.css(position: 'absolute', top: 10, left: 10)

        # start
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 10])

        # moving changes selection
        $(document).trigger mousemoveEvent(editorView: editorView, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editorView, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

      it "selects and scrolls if the mouse is dragged outside of the editor view view itself", ->
        editorView.vScrollMargin = 0
        editorView.attachToDom(heightInLines: 5)
        editorView.scrollToBottom()

        spyOn(window, 'setInterval').andCallFake ->

        # start
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [12, 0])
        originalScrollTop = editorView.scrollTop()

        # moving changes selection
        $(document).trigger mousemoveEvent(editorView: editorView, pageX: 0, pageY: -1)
        expect(editorView.scrollTop()).toBe originalScrollTop - editorView.lineHeight

        # every mouse move selects more text
        for x in [0..10]
          $(document).trigger mousemoveEvent(editorView: editorView, pageX: 0, pageY: -1)

        expect(editorView.scrollTop()).toBe 0

      it "ignores non left-click and drags", ->
        editorView.attachToDom()
        editorView.css(position: 'absolute', top: 10, left: 10)

        event = mousedownEvent(editorView: editorView, point: [4, 10])
        event.originalEvent.which = 2
        editorView.renderedLines.trigger(event)
        $(document).trigger mousemoveEvent(editorView: editorView, point: [5, 27])
        $(document).trigger 'mouseup'

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 4, column: 10})

      it "ignores ctrl-click and drags", ->
        editorView.attachToDom()
        editorView.css(position: 'absolute', top: 10, left: 10)

        event = mousedownEvent(editorView: editorView, point: [4, 10])
        event.ctrlKey = true
        editorView.renderedLines.trigger(event)
        $(document).trigger mousemoveEvent(editorView: editorView, point: [5, 27])
        $(document).trigger 'mouseup'

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 4, column: 10})

    describe "double-click and drag", ->
      it "selects the word under the cursor, then continues to select by word in either direction as the mouse is dragged", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 8], originalEvent: {detail: 1})
        editorView.renderedLines.trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [0, 8], originalEvent: {detail: 2})
        expect(editor.getSelectedText()).toBe "quicksort"

        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [1, 8])
        expect(editor.getSelectedBufferRange()).toEqual [[0, 4], [1, 10]]
        expect(editor.getCursorBufferPosition()).toEqual [1, 10]

        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [0, 1])
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 13]]
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]

        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 13]]

        # shift-clicking still selects by word, but does not preserve the initial range
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [5, 25], originalEvent: {detail: 1}, shiftKey: true)
        editorView.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 13], [5, 27]]

    describe "triple-click and drag", ->
      it "expands the initial selection linewise in either direction", ->
        editorView.attachToDom()

        # triple click
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 7], originalEvent: {detail: 2})
        $(document).trigger 'mouseup'
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 7], originalEvent: {detail: 3})
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [5, 0]]

        # moving changes selection linewise
        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [5, 27])
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [6, 0]]
        expect(editor.getCursorBufferPosition()).toEqual [6, 0]

        # moving changes selection linewise
        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [2, 27])
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [5, 0]]
        expect(editor.getCursorBufferPosition()).toEqual [2, 0]

        # mouse up may occur outside of editorView, but still need to halt selection
        $(document).trigger 'mouseup'

    describe "meta-click and drag", ->
      it "adds an additional selection", ->
        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [4, 10])
        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [5, 27])
        editorView.renderedLines.trigger 'mouseup'

        editorView.renderedLines.trigger mousedownEvent(editorView: editorView, point: [6, 10], metaKey: true)
        editorView.renderedLines.trigger mousemoveEvent(editorView: editorView, point: [8, 27], metaKey: true)
        editorView.renderedLines.trigger 'mouseup'

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[4, 10], [5, 27]]
        expect(selection2.getScreenRange()).toEqual [[6, 10], [8, 27]]

    describe "mousedown on the fold icon of a foldable line number", ->
      it "toggles folding on the clicked buffer row", ->
        expect(editor.isFoldedAtScreenRow(1)).toBe false
        editorView.gutter.find('.line-number:eq(1) .icon-right').mousedown()
        expect(editor.isFoldedAtScreenRow(1)).toBe true
        editorView.gutter.find('.line-number:eq(1) .icon-right').mousedown()
        expect(editor.isFoldedAtScreenRow(1)).toBe false

  describe "when text input events are triggered on the hidden input element", ->
    it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
      editorView.attachToDom()
      editor.setCursorScreenPosition(row: 1, column: 6)

      expect(buffer.lineForRow(1).charAt(6)).not.toBe 'q'

      editorView.hiddenInput.textInput 'q'

      expect(buffer.lineForRow(1).charAt(6)).toBe 'q'
      expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 7)
      expect(editorView.renderedLines.find('.line:eq(1)')).toHaveText buffer.lineForRow(1)

  describe "selection rendering", ->
    [charWidth, lineHeight, selection, selectionView] = []

    beforeEach ->
      editorView.attachToDom()
      editorView.width(500)
      { charWidth, lineHeight } = editorView
      selection = editor.getSelection()
      selectionView = editorView.getSelectionView()

    describe "when a selection is added", ->
      it "adds a selection view for it with the proper regions", ->
        editorView.editor.addSelectionForBufferRange([[2, 7], [2, 25]])
        selectionViews = editorView.getSelectionViews()
        expect(selectionViews.length).toBe 2
        expect(selectionViews[1].regions.length).toBe 1
        region = selectionViews[1].regions[0]
        expect(region.position().top).toBeCloseTo(2 * lineHeight)
        expect(region.position().left).toBeCloseTo(7 * charWidth)
        expect(region.height()).toBeCloseTo lineHeight
        expect(region.width()).toBeCloseTo((25 - 7) * charWidth)

    describe "when a selection changes", ->
      describe "when the selection is within a single line", ->
        it "covers the selection's range with a single region", ->
          selection.setBufferRange([[2, 7], [2, 25]])

          expect(selectionView.regions.length).toBe 1
          region = selectionView.regions[0]
          expect(region.position().top).toBeCloseTo(2 * lineHeight)
          expect(region.position().left).toBeCloseTo(7 * charWidth)
          expect(region.height()).toBeCloseTo lineHeight
          expect(region.width()).toBeCloseTo((25 - 7) * charWidth)

      describe "when the selection spans 2 lines", ->
        it "covers the selection's range with 2 regions", ->
          selection.setBufferRange([[2,7],[3,25]])

          expect(selectionView.regions.length).toBe 2

          region1 = selectionView.regions[0]
          expect(region1.position().top).toBeCloseTo(2 * lineHeight)
          expect(region1.position().left).toBeCloseTo(7 * charWidth)
          expect(region1.height()).toBeCloseTo lineHeight

          expect(region1.width()).toBeCloseTo(editorView.renderedLines.outerWidth() - region1.position().left)
          region2 = selectionView.regions[1]
          expect(region2.position().top).toBeCloseTo(3 * lineHeight)
          expect(region2.position().left).toBeCloseTo(0)
          expect(region2.height()).toBeCloseTo lineHeight
          expect(region2.width()).toBeCloseTo(25 * charWidth)

      describe "when the selection spans more than 2 lines", ->
        it "covers the selection's range with 3 regions", ->
          selection.setBufferRange([[2,7],[6,25]])

          expect(selectionView.regions.length).toBe 3

          region1 = selectionView.regions[0]
          expect(region1.position().top).toBeCloseTo(2 * lineHeight)
          expect(region1.position().left).toBeCloseTo(7 * charWidth)
          expect(region1.height()).toBeCloseTo lineHeight

          expect(region1.width()).toBeCloseTo(editorView.renderedLines.outerWidth() - region1.position().left)
          region2 = selectionView.regions[1]
          expect(region2.position().top).toBeCloseTo(3 * lineHeight)
          expect(region2.position().left).toBeCloseTo(0)
          expect(region2.height()).toBeCloseTo(3 * lineHeight)
          expect(region2.width()).toBeCloseTo(editorView.renderedLines.outerWidth())

          # resizes with the editorView
          expect(editorView.width()).toBeLessThan(800)
          editorView.width(800)
          editorView.resize() # call to trigger the resize event.

          region2 = selectionView.regions[1]
          expect(region2.width()).toBe(editorView.renderedLines.outerWidth())

          region3 = selectionView.regions[2]
          expect(region3.position().top).toBeCloseTo(6 * lineHeight)
          expect(region3.position().left).toBeCloseTo(0)
          expect(region3.height()).toBeCloseTo lineHeight
          expect(region3.width()).toBeCloseTo(25 * charWidth)

      it "clears previously drawn regions before creating new ones", ->
        selection.setBufferRange([[2,7],[4,25]])
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.region').length).toBe 3

        selectionView.updateDisplay()
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.region').length).toBe 3

    describe "when a selection merges with another selection", ->
      it "removes the merged selection view", ->
        editor = editorView.editor
        editor.setCursorScreenPosition([4, 10])
        editor.selectToScreenPosition([5, 27])
        editor.addCursorAtScreenPosition([3, 10])
        editor.selectToScreenPosition([6, 27])

        expect(editorView.getSelectionViews().length).toBe 1
        expect(editorView.find('.region').length).toBe 3

    describe "when a selection is added and removed before the display is updated", ->
      it "does not attempt to render the selection", ->
        # don't update display until we request it
        jasmine.unspy(editorView, 'requestDisplayUpdate')
        spyOn(editorView, 'requestDisplayUpdate')

        editor = editorView.editor
        selection = editor.addSelectionForBufferRange([[3, 0], [3, 4]])
        selection.destroy()
        editorView.updateDisplay()
        expect(editorView.getSelectionViews().length).toBe 1

    describe "when the selection is created with the selectAll event", ->
      it "does not scroll to the end of the buffer", ->
        editorView.height(150)
        editor.selectAll()
        expect(editorView.scrollTop()).toBe 0

        # regression: does not scroll the scroll view when the editorView is refocused
        editorView.hiddenInput.blur()
        editorView.hiddenInput.focus()
        expect(editorView.scrollTop()).toBe 0
        expect(editorView.scrollView.scrollTop()).toBe 0

        # does autoscroll when the selection is cleared
        editor.moveCursorDown()
        expect(editorView.scrollTop()).toBeGreaterThan(0)

    describe "selection autoscrolling and highlighting when setting selected buffer range", ->
      beforeEach ->
        setEditorHeightInLines(editorView, 4)

      describe "if autoscroll is true", ->
        it "centers the viewport on the selection if its vertical center is currently offscreen", ->
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editorView.scrollTop()).toBe 0

          editor.setSelectedBufferRange([[6, 0], [8, 0]], autoscroll: true)
          expect(editorView.scrollTop()).toBe 5 * editorView.lineHeight

        it "highlights the selection if autoscroll is true", ->
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editorView.getSelectionView()).toHaveClass 'highlighted'
          advanceClock(1000)
          expect(editorView.getSelectionView()).not.toHaveClass 'highlighted'

          editor.setSelectedBufferRange([[3, 0], [5, 0]], autoscroll: true)
          expect(editorView.getSelectionView()).toHaveClass 'highlighted'

          advanceClock(500)
          spyOn(editorView.getSelectionView(), 'removeClass').andCallThrough()
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editorView.getSelectionView().removeClass).toHaveBeenCalledWith('highlighted')
          expect(editorView.getSelectionView()).toHaveClass 'highlighted'

          advanceClock(500)
          expect(editorView.getSelectionView()).toHaveClass 'highlighted'

      describe "if autoscroll is false", ->
        it "does not scroll to the selection or the cursor", ->
          editorView.scrollToBottom()
          scrollTopBefore = editorView.scrollTop()
          editor.setSelectedBufferRange([[0, 0], [1, 0]], autoscroll: false)
          expect(editorView.scrollTop()).toBe scrollTopBefore

      describe "if autoscroll is not specified", ->
        it "autoscrolls to the cursor as normal", ->
          editorView.scrollToBottom()
          editor.setSelectedBufferRange([[0, 0], [1, 0]])
          expect(editorView.scrollTop()).toBe 0

  describe "cursor rendering", ->
    describe "when the cursor moves", ->
      charWidth = null

      beforeEach ->
        editorView.attachToDom()
        editorView.vScrollMargin = 3
        editorView.hScrollMargin = 5
        {charWidth} = editorView

      it "repositions the cursor's view on screen", ->
        editor.setCursorScreenPosition(row: 2, column: 2)
        expect(editorView.getCursorView().position()).toEqual(top: 2 * editorView.lineHeight, left: 2 * editorView.charWidth)

      it "hides the cursor when the selection is non-empty, and shows it otherwise", ->
        cursorView = editorView.getCursorView()
        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(cursorView).toBeVisible()

        editor.setSelectedBufferRange([[0, 0], [3, 0]])
        expect(editor.getSelection().isEmpty()).toBeFalsy()
        expect(cursorView).toBeHidden()

        editor.setCursorBufferPosition([1, 3])
        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(cursorView).toBeVisible()

      it "moves the hiddenInput to the same position with cursor's view", ->
        editor.setCursorScreenPosition(row: 2, column: 2)
        expect(editorView.getCursorView().offset()).toEqual(editorView.hiddenInput.offset())

      describe "when the editor view is using a variable-width font", ->
        beforeEach ->
          editorView.setFontFamily('sans-serif')

        describe "on #darwin or #linux", ->
          it "correctly positions the cursor", ->
            editor.setCursorBufferPosition([3, 30])
            expect(editorView.getCursorView().position()).toEqual {top: 3 * editorView.lineHeight, left: 178}
            editor.setCursorBufferPosition([3, Infinity])
            expect(editorView.getCursorView().position()).toEqual {top: 3 * editorView.lineHeight, left: 353}

        describe "on #win32", ->
          it "correctly positions the cursor", ->
            editor.setCursorBufferPosition([3, 30])
            expect(editorView.getCursorView().position()).toEqual {top: 3 * editorView.lineHeight, left: 175}
            editor.setCursorBufferPosition([3, Infinity])
            expect(editorView.getCursorView().position()).toEqual {top: 3 * editorView.lineHeight, left: 346}

      describe "autoscrolling", ->
        it "only autoscrolls when the last cursor is moved", ->
          editor.setCursorBufferPosition([11,0])
          editor.addCursorAtBufferPosition([6,50])
          [cursor1, cursor2] = editor.getCursors()

          spyOn(editorView, 'scrollToPixelPosition')
          cursor1.setScreenPosition([10, 10])
          expect(editorView.scrollToPixelPosition).not.toHaveBeenCalled()

          cursor2.setScreenPosition([11, 11])
          expect(editorView.scrollToPixelPosition).toHaveBeenCalled()

        it "does not autoscroll if the 'autoscroll' option is false", ->
          editor.setCursorBufferPosition([11,0])
          spyOn(editorView, 'scrollToPixelPosition')
          editor.setCursorScreenPosition([10, 10], autoscroll: false)
          expect(editorView.scrollToPixelPosition).not.toHaveBeenCalled()

        it "autoscrolls to cursor if autoscroll is true, even if the position does not change", ->
          spyOn(editorView, 'scrollToPixelPosition')
          editor.setCursorScreenPosition([4, 10], autoscroll: false)
          editor.setCursorScreenPosition([4, 10])
          expect(editorView.scrollToPixelPosition).toHaveBeenCalled()
          editorView.scrollToPixelPosition.reset()

          editor.setCursorBufferPosition([4, 10])
          expect(editorView.scrollToPixelPosition).toHaveBeenCalled()

        it "does not autoscroll the cursor based on a buffer change, unless the buffer change was initiated by the cursor", ->
          lastVisibleRow = editorView.getLastVisibleScreenRow()
          editor.addCursorAtBufferPosition([lastVisibleRow, 0])
          spyOn(editorView, 'scrollToPixelPosition')
          buffer.insert([lastVisibleRow, 0], "\n\n")
          expect(editorView.scrollToPixelPosition).not.toHaveBeenCalled()
          editor.insertText('\n\n')
          expect(editorView.scrollToPixelPosition.callCount).toBe 1

        it "autoscrolls on undo/redo", ->
          spyOn(editorView, 'scrollToPixelPosition')
          editor.insertText('\n\n')
          expect(editorView.scrollToPixelPosition.callCount).toBe 1
          editor.undo()
          expect(editorView.scrollToPixelPosition.callCount).toBe 2
          editor.redo()
          expect(editorView.scrollToPixelPosition.callCount).toBe 3

        describe "when the last cursor exceeds the upper or lower scroll margins", ->
          describe "when the editor view is taller than twice the vertical scroll margin", ->
            it "sets the scrollTop so the cursor remains within the scroll margin", ->
              setEditorHeightInLines(editorView, 10)

              _.times 6, -> editor.moveCursorDown()
              expect(editorView.scrollTop()).toBe(0)

              editor.moveCursorDown()
              expect(editorView.scrollTop()).toBe(editorView.lineHeight)

              editor.moveCursorDown()
              expect(editorView.scrollTop()).toBe(editorView.lineHeight * 2)

              _.times 3, -> editor.moveCursorUp()

              editor.moveCursorUp()
              expect(editorView.scrollTop()).toBe(editorView.lineHeight)

              editor.moveCursorUp()
              expect(editorView.scrollTop()).toBe(0)

          describe "when the editor view is shorter than twice the vertical scroll margin", ->
            it "sets the scrollTop based on a reduced scroll margin, which prevents a jerky tug-of-war between upper and lower scroll margins", ->
              setEditorHeightInLines(editorView, 5)

              _.times 3, -> editor.moveCursorDown()

              expect(editorView.scrollTop()).toBe(editorView.lineHeight)

              editor.moveCursorUp()
              expect(editorView.renderedLines.css('top')).toBe "0px"

        describe "when the last cursor exceeds the right or left scroll margins", ->
          describe "when soft-wrap is disabled", ->
            describe "when the editor view is wider than twice the horizontal scroll margin", ->
              it "sets the scrollView's scrollLeft so the cursor remains within the scroll margin", ->
                setEditorWidthInChars(editorView, 30)

                # moving right
                editor.setCursorScreenPosition([2, 24])
                expect(editorView.scrollLeft()).toBe 0

                editor.setCursorScreenPosition([2, 25])
                expect(editorView.scrollLeft()).toBe charWidth

                editor.setCursorScreenPosition([2, 28])
                expect(editorView.scrollLeft()).toBe charWidth * 4

                # moving left
                editor.setCursorScreenPosition([2, 9])
                expect(editorView.scrollLeft()).toBe charWidth * 4

                editor.setCursorScreenPosition([2, 8])
                expect(editorView.scrollLeft()).toBe charWidth * 3

                editor.setCursorScreenPosition([2, 5])
                expect(editorView.scrollLeft()).toBe 0

            describe "when the editor view is narrower than twice the horizontal scroll margin", ->
              it "sets the scrollView's scrollLeft based on a reduced horizontal scroll margin, to prevent a jerky tug-of-war between right and left scroll margins", ->
                editorView.hScrollMargin = 6
                setEditorWidthInChars(editorView, 7)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editorView.scrollLeft()).toBe(0)

                editor.setCursorScreenPosition([2, 4])
                window.advanceClock()
                expect(editorView.scrollLeft()).toBe(charWidth)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editorView.scrollLeft()).toBe(0)

          describe "when soft-wrap is enabled", ->
            beforeEach ->
              editor.setSoftWrap(true)

            it "does not scroll the buffer horizontally", ->
              editorView.width(charWidth * 30)

              # moving right
              editor.setCursorScreenPosition([2, 24])
              expect(editorView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 25])
              expect(editorView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 28])
              expect(editorView.scrollLeft()).toBe 0

              # moving left
              editor.setCursorScreenPosition([2, 9])
              expect(editorView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 8])
              expect(editorView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 5])
              expect(editorView.scrollLeft()).toBe 0

  describe "when editor:toggle-soft-wrap is toggled", ->
    describe "when the text exceeds the editor view width and the scroll-view is horizontally scrolled", ->
      it "wraps the text and renders properly", ->
        editorView.attachToDom(heightInLines: 30, widthInChars: 30)
        editorView.setWidthInChars(100)
        editor.setText("Fashion axe umami jean shorts retro hashtag carles mumblecore. Photo booth skateboard Austin gentrify occupy ethical. Food truck gastropub keffiyeh, squid deep v pinterest literally sustainable salvia scenester messenger bag. Neutra messenger bag flexitarian four loko, shoreditch VHS pop-up tumblr seitan synth master cleanse. Marfa selvage ugh, raw denim authentic try-hard mcsweeney's trust fund fashion axe actually polaroid viral sriracha. Banh mi marfa plaid single-origin coffee. Pickled mumblecore lomo ugh bespoke.")
        editorView.scrollLeft(editorView.charWidth * 30)
        editorView.trigger "editor:toggle-soft-wrap"
        expect(editorView.scrollLeft()).toBe 0
        expect(editorView.editor.getSoftWrapColumn()).not.toBe 100

  describe "text rendering", ->
    describe "when all lines in the buffer are visible on screen", ->
      beforeEach ->
        editorView.attachToDom()
        expect(editorView.trueHeight()).toBeCloseTo buffer.getLineCount() * editorView.lineHeight

      it "creates a line element for each line in the buffer with the html-escaped text of the line", ->
        expect(editorView.renderedLines.find('.line').length).toEqual(buffer.getLineCount())
        expect(buffer.lineForRow(2)).toContain('<')
        expect(editorView.renderedLines.find('.line:eq(2)').html()).toContain '&lt;'

        # renders empty lines with a non breaking space
        expect(buffer.lineForRow(10)).toBe ''
        expect(editorView.renderedLines.find('.line:eq(10)').html()).toBe '&nbsp;'

      it "syntax highlights code based on the file type", ->
        line0 = editorView.renderedLines.find('.line:first')
        span0 = line0.children('span:eq(0)')
        expect(span0).toMatchSelector '.source.js'
        expect(span0.children('span:eq(0)')).toMatchSelector '.storage.modifier.js'
        expect(span0.children('span:eq(0)').text()).toBe 'var'

        span0_1 = span0.children('span:eq(1)')
        expect(span0_1).toMatchSelector '.meta.function.js'
        expect(span0_1.text()).toBe 'quicksort = function ()'
        expect(span0_1.children('span:eq(0)')).toMatchSelector '.entity.name.function.js'
        expect(span0_1.children('span:eq(0)').text()).toBe "quicksort"
        expect(span0_1.children('span:eq(1)')).toMatchSelector '.keyword.operator.js'
        expect(span0_1.children('span:eq(1)').text()).toBe "="
        expect(span0_1.children('span:eq(2)')).toMatchSelector '.storage.type.function.js'
        expect(span0_1.children('span:eq(2)').text()).toBe "function"
        expect(span0_1.children('span:eq(3)')).toMatchSelector '.punctuation.definition.parameters.begin.js'
        expect(span0_1.children('span:eq(3)').text()).toBe "("
        expect(span0_1.children('span:eq(4)')).toMatchSelector '.punctuation.definition.parameters.end.js'
        expect(span0_1.children('span:eq(4)').text()).toBe ")"

        expect(span0.children('span:eq(2)')).toMatchSelector '.meta.brace.curly.js'
        expect(span0.children('span:eq(2)').text()).toBe "{"

        line12 = editorView.renderedLines.find('.line:eq(11)').children('span:eq(0)')
        expect(line12.children('span:eq(1)')).toMatchSelector '.keyword'

      it "wraps hard tabs in a span", ->
        editor.setText('\t<- hard tab')
        line0 = editorView.renderedLines.find('.line:first')
        span0_0 = line0.children('span:eq(0)').children('span:eq(0)')
        expect(span0_0).toMatchSelector '.hard-tab'
        expect(span0_0.text()).toBe '  '
        expect(span0_0.text().length).toBe editor.getTabLength()

      it "wraps leading whitespace in a span", ->
        line1 = editorView.renderedLines.find('.line:eq(1)')
        span0_0 = line1.children('span:eq(0)').children('span:eq(0)')
        expect(span0_0).toMatchSelector '.leading-whitespace'
        expect(span0_0.text()).toBe '  '

      describe "when the line has trailing whitespace", ->
        it "wraps trailing whitespace in a span", ->
          editor.setText('trailing whitespace ->   ')
          line0 = editorView.renderedLines.find('.line:first')
          span0_last = line0.children('span:eq(0)').children('span:last')
          expect(span0_last).toMatchSelector '.trailing-whitespace'
          expect(span0_last.text()).toBe '   '

      describe "when lines are updated in the buffer", ->
        it "syntax highlights the updated lines", ->
          expect(editorView.renderedLines.find('.line:eq(0) > span:first > span:first')).toMatchSelector '.storage.modifier.js'
          buffer.insert([0, 0], "q")
          expect(editorView.renderedLines.find('.line:eq(0) > span:first > span:first')).not.toMatchSelector '.storage.modifier.js'

          # verify that re-highlighting can occur below the changed line
          buffer.insert([5,0], "/* */")
          buffer.insert([1,0], "/*")
          expect(editorView.renderedLines.find('.line:eq(2) > span:first > span:first')).toMatchSelector '.comment'

    describe "when some lines at the end of the buffer are not visible on screen", ->
      beforeEach ->
        editorView.attachToDom(heightInLines: 5.5)

      it "only renders the visible lines plus the overdrawn lines, setting the padding-bottom of the lines element to account for the missing lines", ->
        expect(editorView.renderedLines.find('.line').length).toBe 8
        expectedPaddingBottom = (buffer.getLineCount() - 8) * editorView.lineHeight
        expect(editorView.renderedLines.css('padding-bottom')).toBe "#{expectedPaddingBottom}px"
        expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
        expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

      it "renders additional lines when the editor view is resized", ->
        setEditorHeightInLines(editorView, 10)
        $(window).trigger 'resize'

        expect(editorView.renderedLines.find('.line').length).toBe 12
        expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
        expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

      it "renders correctly when scrolling after text is added to the buffer", ->
        editor.insertText("1\n")
        _.times 4, -> editor.moveCursorDown()
        expect(editorView.renderedLines.find('.line:eq(2)').text()).toBe editor.lineForBufferRow(2)
        expect(editorView.renderedLines.find('.line:eq(7)').text()).toBe editor.lineForBufferRow(7)

      it "renders correctly when scrolling after text is removed from buffer", ->
        editor.getBuffer().delete([[0,0],[1,0]])
        expect(editorView.renderedLines.find('.line:eq(0)').text()).toBe editor.lineForBufferRow(0)
        expect(editorView.renderedLines.find('.line:eq(5)').text()).toBe editor.lineForBufferRow(5)

        editorView.scrollTop(3 * editorView.lineHeight)
        expect(editorView.renderedLines.find('.line:first').text()).toBe editor.lineForBufferRow(1)
        expect(editorView.renderedLines.find('.line:last').text()).toBe editor.lineForBufferRow(10)

      describe "when creating and destroying folds that are longer than the visible lines", ->
        describe "when the cursor precedes the fold when it is destroyed", ->
          it "renders lines and line numbers correctly", ->
            scrollHeightBeforeFold = editorView.scrollView.prop('scrollHeight')
            fold = editor.createFold(1, 9)
            fold.destroy()
            expect(editorView.scrollView.prop('scrollHeight')).toBe scrollHeightBeforeFold

            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

            expect(editorView.gutter.find('.line-number').length).toBe 8
            expect(editorView.gutter.find('.line-number:last').intValue()).toBe 8

            editorView.scrollTop(4 * editorView.lineHeight)
            expect(editorView.renderedLines.find('.line').length).toBe 10
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

        describe "when the cursor follows the fold when it is destroyed", ->
          it "renders lines and line numbers correctly", ->
            fold = editor.createFold(1, 9)
            editor.setCursorBufferPosition([10, 0])
            fold.destroy()

            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            expect(editorView.gutter.find('.line-number').length).toBe 8
            expect(editorView.gutter.find('.line-number:last').text()).toBe '13'

            editorView.scrollTop(4 * editorView.lineHeight)

            expect(editorView.renderedLines.find('.line').length).toBe 10
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

      describe "when scrolling vertically", ->
        describe "when scrolling less than the editor view's height", ->
          it "draws new lines and removes old lines when the last visible line will exceed the last rendered line", ->
            expect(editorView.renderedLines.find('.line').length).toBe 8

            editorView.scrollTop(editorView.lineHeight * 1.5)
            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

            editorView.scrollTop(editorView.lineHeight * 3.5) # first visible row will be 3, last will be 8
            expect(editorView.renderedLines.find('.line').length).toBe 10
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editorView.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank
            expect(editorView.gutter.find('.line-number:first').intValue()).toBe 2
            expect(editorView.gutter.find('.line-number:last').intValue()).toBe 11

            # here we don't scroll far enough to trigger additional rendering
            editorView.scrollTop(editorView.lineHeight * 5.5) # first visible row will be 5, last will be 10
            expect(editorView.renderedLines.find('.line').length).toBe 10
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editorView.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank
            expect(editorView.gutter.find('.line-number:first').intValue()).toBe 2
            expect(editorView.gutter.find('.line-number:last').intValue()).toBe 11

            editorView.scrollTop(editorView.lineHeight * 7.5) # first visible row is 7, last will be 12
            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(5)
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            editorView.scrollTop(editorView.lineHeight * 3.5) # first visible row will be 3, last will be 8
            expect(editorView.renderedLines.find('.line').length).toBe 10
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editorView.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank

            editorView.scrollTop(0)
            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

        describe "when scrolling more than the editors height", ->
          it "removes lines that are offscreen and not in range of the overdraw and builds lines that become visible", ->
            editorView.scrollTop(editorView.layerHeight - editorView.scrollView.height())
            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(5)
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            editorView.verticalScrollbar.scrollBottom(0)
            editorView.verticalScrollbar.trigger 'scroll'
            expect(editorView.renderedLines.find('.line').length).toBe 8
            expect(editorView.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editorView.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

        it "adjusts the vertical padding of the lines element to account for non-rendered lines", ->
          editorView.scrollTop(editorView.lineHeight * 3)
          firstVisibleBufferRow = 3
          expectedPaddingTop = (firstVisibleBufferRow - editorView.lineOverdraw) * editorView.lineHeight
          expect(editorView.renderedLines.css('padding-top')).toBe "#{expectedPaddingTop}px"

          lastVisibleBufferRow = Math.ceil(3 + 5.5) # scroll top in lines + height in lines
          lastOverdrawnRow = lastVisibleBufferRow + editorView.lineOverdraw
          expectedPaddingBottom = ((buffer.getLineCount() - lastOverdrawnRow) * editorView.lineHeight)
          expect(editorView.renderedLines.css('padding-bottom')).toBe "#{expectedPaddingBottom}px"

          editorView.scrollToBottom()
          # scrolled to bottom, first visible row is 5 and first rendered row is 3
          firstVisibleBufferRow = Math.floor(buffer.getLineCount() - 5.5)
          firstOverdrawnBufferRow = firstVisibleBufferRow - editorView.lineOverdraw
          expectedPaddingTop = firstOverdrawnBufferRow * editorView.lineHeight
          expect(editorView.renderedLines.css('padding-top')).toBe "#{expectedPaddingTop}px"
          expect(editorView.renderedLines.css('padding-bottom')).toBe "0px"

    describe "when lines are added", ->
      beforeEach ->
        editorView.attachToDom(heightInLines: 5)

      describe "when the change precedes the first rendered row", ->
        it "inserts and removes rendered lines to account for upstream change", ->
          editorView.scrollToBottom()
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[1,0], [3,0]], "1\n2\n3\n")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

      describe "when the change straddles the first rendered row", ->
        it "doesn't render rows that were not previously rendered", ->
          editorView.scrollToBottom()

          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[2,0], [7,0]], "2\n3\n4\n5\n6\n7\n8\n9\n")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

      describe "when the change straddles the last rendered row", ->
        it "doesn't render rows that were not previously rendered", ->
          buffer.change([[2,0], [7,0]], "2\n3\n4\n5\n6\n7\n8\n")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the change the follows the last rendered row", ->
        it "does not change the rendered lines", ->
          buffer.change([[12,0], [12,0]], "12\n13\n14\n")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      it "increases the width of the rendered lines element to be either the width of the longest line or the width of the scrollView (whichever is longer)", ->
        maxLineLength = editor.getMaxScreenLineLength()
        setEditorWidthInChars(editorView, maxLineLength)
        widthBefore = editorView.renderedLines.width()
        expect(widthBefore).toBe editorView.scrollView.width() + 20
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editorView.renderedLines.width()).toBeGreaterThan widthBefore

    describe "when lines are removed", ->
      beforeEach ->
        editorView.attachToDom(heightInLines: 5)

      it "sets the rendered screen line's width to either the max line length or the scollView's width (whichever is greater)", ->
        maxLineLength = editor.getMaxScreenLineLength()
        setEditorWidthInChars(editorView, maxLineLength)
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editorView.renderedLines.width()).toBeGreaterThan editorView.scrollView.width()
        widthBefore = editorView.renderedLines.width()
        buffer.delete([[12, 0], [12, Infinity]])
        expect(editorView.renderedLines.width()).toBe editorView.scrollView.width() + 20

      describe "when the change the precedes the first rendered row", ->
        it "removes rendered lines to account for upstream change", ->
          editorView.scrollToBottom()
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[1,0], [2,0]], "")
          expect(editorView.renderedLines.find(".line").length).toBe 6
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(11)

      describe "when the change straddles the first rendered row", ->
        it "renders the correct rows", ->
          editorView.scrollToBottom()
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[7,0], [11,0]], "1\n2\n")
          expect(editorView.renderedLines.find(".line").length).toBe 5
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(10)

      describe "when the change straddles the last rendered row", ->
        it "renders the correct rows", ->
          buffer.change([[2,0], [7,0]], "")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the change the follows the last rendered row", ->
        it "does not change the rendered lines", ->
          buffer.change([[10,0], [12,0]], "")
          expect(editorView.renderedLines.find(".line").length).toBe 7
          expect(editorView.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editorView.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the last line is removed when the editor view is scrolled to the bottom", ->
        it "reduces the editor view's scrollTop (due to the reduced total scroll height) and renders the correct screen lines", ->
          editor.setCursorScreenPosition([Infinity, Infinity])
          editor.insertText('\n\n\n')
          editorView.scrollToBottom()

          expect(buffer.getLineCount()).toBe 16

          initialScrollTop = editorView.scrollTop()
          expect(editorView.firstRenderedScreenRow).toBe 9
          expect(editorView.lastRenderedScreenRow).toBe 15

          editor.backspace()

          expect(editorView.scrollTop()).toBeLessThan initialScrollTop
          expect(editorView.firstRenderedScreenRow).toBe 9
          expect(editorView.lastRenderedScreenRow).toBe 14

          expect(editorView.find('.line').length).toBe 6

          editor.backspace()
          expect(editorView.firstRenderedScreenRow).toBe 9
          expect(editorView.lastRenderedScreenRow).toBe 13

          expect(editorView.find('.line').length).toBe 5

          editor.backspace()
          expect(editorView.firstRenderedScreenRow).toBe 6
          expect(editorView.lastRenderedScreenRow).toBe 12

          expect(editorView.find('.line').length).toBe 7

    describe "when folding leaves less then a screen worth of text (regression)", ->
      it "renders lines properly", ->
        editorView.lineOverdraw = 1
        editorView.attachToDom(heightInLines: 5)
        editorView.editor.foldBufferRow(4)
        editorView.editor.foldBufferRow(0)

        expect(editorView.renderedLines.find('.line').length).toBe 1
        expect(editorView.renderedLines.find('.line').text()).toBe buffer.lineForRow(0)

    describe "when folding leaves fewer screen lines than the first rendered screen line (regression)", ->
      it "clears all screen lines and does not throw any exceptions", ->
        editorView.lineOverdraw = 1
        editorView.attachToDom(heightInLines: 5)
        editorView.scrollToBottom()
        editorView.editor.foldBufferRow(0)
        expect(editorView.renderedLines.find('.line').length).toBe 1
        expect(editorView.renderedLines.find('.line').text()).toBe buffer.lineForRow(0)

    describe "when autoscrolling at the end of the document", ->
      it "renders lines properly", ->
        editorView.edit(atom.project.openSync('two-hundred.txt'))
        editorView.attachToDom(heightInLines: 5.5)

        expect(editorView.renderedLines.find('.line').length).toBe 8

        editor.moveCursorToBottom()

        expect(editorView.renderedLines.find('.line').length).toBe 8

    describe "when line has a character that could push it to be too tall (regression)", ->
      it "does renders the line at a consistent height", ->
        editorView.attachToDom()
        buffer.insert([0, 0], "–")
        expect(editorView.find('.line:eq(0)').outerHeight()).toBe editorView.find('.line:eq(1)').outerHeight()

    describe "when editor.showInvisibles config is set to true", ->
      it "displays spaces, tabs, and newlines using visible non-empty values", ->
        editor.setText " a line with tabs\tand spaces "
        editorView.attachToDom()

        expect(atom.config.get("editor.showInvisibles")).toBeFalsy()
        expect(editorView.renderedLines.find('.line').text()).toBe " a line with tabs  and spaces "

        atom.config.set("editor.showInvisibles", true)
        space = editorView.invisibles?.space
        expect(space).toBeTruthy()
        tab = editorView.invisibles?.tab
        expect(tab).toBeTruthy()
        eol = editorView.invisibles?.eol
        expect(eol).toBeTruthy()
        expect(editorView.renderedLines.find('.line').text()).toBe "#{space}a line with tabs#{tab} and spaces#{space}#{eol}"

        atom.config.set("editor.showInvisibles", false)
        expect(editorView.renderedLines.find('.line').text()).toBe " a line with tabs  and spaces "

      it "displays newlines as their own token outside of the other tokens scope", ->
        editorView.setShowInvisibles(true)
        editorView.attachToDom()
        editor.setText "var"
        expect(editorView.find('.line').html()).toBe '<span class="source js"><span class="storage modifier js">var</span></span><span class="invisible-character">¬</span>'

      it "allows invisible glyphs to be customized via the editor.invisibles config", ->
        editor.setText(" \t ")
        editorView.attachToDom()
        atom.config.set("editor.showInvisibles", true)
        atom.config.set("editor.invisibles", eol: ";", space: "_", tab: "tab")
        expect(editorView.find(".line:first").text()).toBe "_tab _;"

      it "displays trailing carriage return using a visible non-empty value", ->
        editor.setText "a line that ends with a carriage return\r\n"
        editorView.attachToDom()

        expect(atom.config.get("editor.showInvisibles")).toBeFalsy()
        expect(editorView.renderedLines.find('.line:first').text()).toBe "a line that ends with a carriage return"

        atom.config.set("editor.showInvisibles", true)
        cr = editorView.invisibles?.cr
        expect(cr).toBeTruthy()
        eol = editorView.invisibles?.eol
        expect(eol).toBeTruthy()
        expect(editorView.renderedLines.find('.line:first').text()).toBe "a line that ends with a carriage return#{cr}#{eol}"

      describe "when wrapping is on", ->
        beforeEach ->
          editor.setSoftWrap(true)

        it "doesn't show the end of line invisible at the end of lines broken due to wrapping", ->
          editor.setText "a line that wraps"
          editorView.attachToDom()
          editorView.setWidthInChars(6)
          atom.config.set "editor.showInvisibles", true
          space = editorView.invisibles?.space
          expect(space).toBeTruthy()
          eol = editorView.invisibles?.eol
          expect(eol).toBeTruthy()
          expect(editorView.renderedLines.find('.line:first').text()).toBe "a line#{space}"
          expect(editorView.renderedLines.find('.line:last').text()).toBe "wraps#{eol}"

        it "displays trailing carriage return using a visible non-empty value", ->
          editor.setText "a line that\r\n"
          editorView.attachToDom()
          editorView.setWidthInChars(6)
          atom.config.set "editor.showInvisibles", true
          space = editorView.invisibles?.space
          expect(space).toBeTruthy()
          cr = editorView.invisibles?.cr
          expect(cr).toBeTruthy()
          eol = editorView.invisibles?.eol
          expect(eol).toBeTruthy()
          expect(editorView.renderedLines.find('.line:first').text()).toBe "a line#{space}"
          expect(editorView.renderedLines.find('.line:eq(1)').text()).toBe "that#{cr}#{eol}"
          expect(editorView.renderedLines.find('.line:last').text()).toBe "#{eol}"

    describe "when editor.showIndentGuide is set to true", ->
      it "adds an indent-guide class to each leading whitespace span", ->
        editorView.attachToDom()

        expect(atom.config.get("editor.showIndentGuide")).toBeFalsy()
        atom.config.set("editor.showIndentGuide", true)
        expect(editorView.showIndentGuide).toBeTruthy()

        expect(editorView.renderedLines.find('.line:eq(0) .indent-guide').length).toBe 0

        expect(editorView.renderedLines.find('.line:eq(1) .indent-guide').length).toBe 1
        expect(editorView.renderedLines.find('.line:eq(1) .indent-guide').text()).toBe '  '

        expect(editorView.renderedLines.find('.line:eq(2) .indent-guide').length).toBe 2
        expect(editorView.renderedLines.find('.line:eq(2) .indent-guide').text()).toBe '    '

        expect(editorView.renderedLines.find('.line:eq(3) .indent-guide').length).toBe 2
        expect(editorView.renderedLines.find('.line:eq(3) .indent-guide').text()).toBe '    '

        expect(editorView.renderedLines.find('.line:eq(4) .indent-guide').length).toBe 2
        expect(editorView.renderedLines.find('.line:eq(4) .indent-guide').text()).toBe '    '

        expect(editorView.renderedLines.find('.line:eq(5) .indent-guide').length).toBe 3
        expect(editorView.renderedLines.find('.line:eq(5) .indent-guide').text()).toBe '      '

        expect(editorView.renderedLines.find('.line:eq(6) .indent-guide').length).toBe 3
        expect(editorView.renderedLines.find('.line:eq(6) .indent-guide').text()).toBe '      '

        expect(editorView.renderedLines.find('.line:eq(7) .indent-guide').length).toBe 2
        expect(editorView.renderedLines.find('.line:eq(7) .indent-guide').text()).toBe '    '

        expect(editorView.renderedLines.find('.line:eq(8) .indent-guide').length).toBe 2
        expect(editorView.renderedLines.find('.line:eq(8) .indent-guide').text()).toBe '    '

        expect(editorView.renderedLines.find('.line:eq(9) .indent-guide').length).toBe 1
        expect(editorView.renderedLines.find('.line:eq(9) .indent-guide').text()).toBe '  '

        expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
        expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

        expect(editorView.renderedLines.find('.line:eq(11) .indent-guide').length).toBe 1
        expect(editorView.renderedLines.find('.line:eq(11) .indent-guide').text()).toBe '  '

        expect(editorView.renderedLines.find('.line:eq(12) .indent-guide').length).toBe 0

      describe "when the indentation level on a line before an empty line is changed", ->
        it "updates the indent guide on the empty line", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

          editor.setCursorBufferPosition([9])
          editor.indentSelectedRows()

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

      describe "when the indentation level on a line after an empty line is changed", ->
        it "updates the indent guide on the empty line", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

          editor.setCursorBufferPosition([11])
          editor.indentSelectedRows()

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

      describe "when a line contains only whitespace", ->
        it "displays an indent guide on the line", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)

          editor.setCursorBufferPosition([10])
          editor.indent()
          editor.indent()
          expect(editor.getCursorBufferPosition()).toEqual [10, 4]
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

        it "uses the highest indent guide level from the next or previous non-empty line", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)

          editor.setCursorBufferPosition([1, Infinity])
          editor.insertNewline()
          expect(editor.getCursorBufferPosition()).toEqual [2, 0]
          expect(editorView.renderedLines.find('.line:eq(2) .indent-guide').length).toBe 2
          expect(editorView.renderedLines.find('.line:eq(2) .indent-guide').text()).toBe '    '

      describe "when the line has leading and trailing whitespace", ->
        it "does not display the indent guide in the trailing whitespace", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)

          editor.insertText("/*\n * \n*/")
          expect(editorView.renderedLines.find('.line:eq(1) .indent-guide').length).toBe 1
          expect(editorView.renderedLines.find('.line:eq(1) .indent-guide')).toHaveClass('leading-whitespace')

      describe "when the line is empty and end of show invisibles are enabled", ->
        it "renders the indent guides interleaved with the end of line invisibles", ->
          editorView.attachToDom()
          atom.config.set("editor.showIndentGuide", true)
          atom.config.set("editor.showInvisibles", true)
          eol = editorView.invisibles?.eol

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe "#{eol} "
          expect(editorView.renderedLines.find('.line:eq(10) .invisible-character').text()).toBe eol

          editor.setCursorBufferPosition([9])
          editor.indent()

          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editorView.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe "#{eol}   "
          expect(editorView.renderedLines.find('.line:eq(10) .invisible-character').text()).toBe eol

  describe "when soft-wrap is enabled", ->
    beforeEach ->
      jasmine.unspy(window, 'setTimeout')
      editor.setSoftWrap(true)
      editorView.attachToDom()
      setEditorHeightInLines(editorView, 20)
      setEditorWidthInChars(editorView, 50)
      expect(editorView.editor.getSoftWrapColumn()).toBe 50

    it "wraps lines that are too long to fit within the editor view's width, adjusting cursor positioning accordingly", ->
      expect(editorView.renderedLines.find('.line').length).toBe 16
      expect(editorView.renderedLines.find('.line:eq(3)').text()).toBe "    var pivot = items.shift(), current, left = [], "
      expect(editorView.renderedLines.find('.line:eq(4)').text()).toBe "right = [];"

      editor.setCursorBufferPosition([3, 51], wrapAtSoftNewlines: true)
      expect(editorView.find('.cursor').offset()).toEqual(editorView.renderedLines.find('.line:eq(4)').offset())

      editor.setCursorBufferPosition([4, 0])
      expect(editorView.find('.cursor').offset()).toEqual(editorView.renderedLines.find('.line:eq(5)').offset())

      editor.getSelection().setBufferRange([[6, 30], [6, 55]])
      [region1, region2] = editorView.getSelectionView().regions
      expect(region1.offset().top).toBeCloseTo(editorView.renderedLines.find('.line:eq(7)').offset().top)
      expect(region2.offset().top).toBeCloseTo(editorView.renderedLines.find('.line:eq(8)').offset().top)

    it "handles changes to wrapped lines correctly", ->
      buffer.insert([6, 28], '1234567')
      expect(editorView.renderedLines.find('.line:eq(7)').text()).toBe '      current < pivot ? left1234567.push(current) '
      expect(editorView.renderedLines.find('.line:eq(8)').text()).toBe ': right.push(current);'
      expect(editorView.renderedLines.find('.line:eq(9)').text()).toBe '    }'

    it "changes the max line length and repositions the cursor when the window size changes", ->
      editor.setCursorBufferPosition([3, 60])
      setEditorWidthInChars(editorView, 40)
      expect(editorView.renderedLines.find('.line').length).toBe 19
      expect(editorView.renderedLines.find('.line:eq(4)').text()).toBe "left = [], right = [];"
      expect(editorView.renderedLines.find('.line:eq(5)').text()).toBe "    while(items.length > 0) {"
      expect(editor.bufferPositionForScreenPosition(editor.getCursorScreenPosition())).toEqual [3, 60]

    it "does not wrap the lines of any newly assigned buffers", ->
      otherEditor = atom.project.openSync()
      otherEditor.buffer.setText([1..100].join(''))
      editorView.edit(otherEditor)
      expect(editorView.renderedLines.find('.line').length).toBe(1)

    it "unwraps lines when softwrap is disabled", ->
      editorView.toggleSoftWrap()
      expect(editorView.renderedLines.find('.line:eq(3)').text()).toBe '    var pivot = items.shift(), current, left = [], right = [];'

    it "allows the cursor to move down to the last line", ->
      _.times editor.getLastScreenRow(), -> editor.moveCursorDown()
      expect(editor.getCursorScreenPosition()).toEqual [editor.getLastScreenRow(), 0]
      editor.moveCursorDown()
      expect(editor.getCursorScreenPosition()).toEqual [editor.getLastScreenRow(), 2]

    it "allows the cursor to move up to a shorter soft wrapped line", ->
      editor.setCursorScreenPosition([11, 15])
      editor.moveCursorUp()
      expect(editor.getCursorScreenPosition()).toEqual [10, 10]
      editor.moveCursorUp()
      editor.moveCursorUp()
      expect(editor.getCursorScreenPosition()).toEqual [8, 15]

    it "it allows the cursor to wrap when moving horizontally past the beginning / end of a wrapped line", ->
      editor.setCursorScreenPosition([11, 0])
      editor.moveCursorLeft()
      expect(editor.getCursorScreenPosition()).toEqual [10, 10]

      editor.moveCursorRight()
      expect(editor.getCursorScreenPosition()).toEqual [11, 0]

    it "calls .setWidthInChars() when the editor view is attached because now its dimensions are available to calculate it", ->
      otherEditor = new EditorView(editor: atom.project.openSync('sample.js'))
      spyOn(otherEditor, 'setWidthInChars')

      otherEditor.editor.setSoftWrap(true)
      expect(otherEditor.setWidthInChars).not.toHaveBeenCalled()

      otherEditor.simulateDomAttachment()
      expect(otherEditor.setWidthInChars).toHaveBeenCalled()
      otherEditor.remove()

    describe "when the editor view's width changes", ->
      it "updates the width in characters on the edit session", ->
        previousSoftWrapColumn = editor.getSoftWrapColumn()

        spyOn(editorView, 'setWidthInChars').andCallThrough()
        editorView.width(editorView.width() / 2)

        waitsFor ->
          editorView.setWidthInChars.callCount > 0

        runs ->
          expect(editor.getSoftWrapColumn()).toBeLessThan previousSoftWrapColumn

  describe "gutter rendering", ->
    beforeEach ->
      editorView.attachToDom(heightInLines: 5.5)

    it "creates a line number element for each visible line with &nbsp; padding to the left of the number", ->
      expect(editorView.gutter.find('.line-number').length).toBe 8
      expect(editorView.find('.line-number:first').html()).toMatch /^&nbsp;1/
      expect(editorView.gutter.find('.line-number:last').html()).toMatch /^&nbsp;8/

      # here we don't scroll far enough to trigger additional rendering
      editorView.scrollTop(editorView.lineHeight * 1.5)
      expect(editorView.renderedLines.find('.line').length).toBe 8
      expect(editorView.gutter.find('.line-number:first').html()).toMatch /^&nbsp;1/
      expect(editorView.gutter.find('.line-number:last').html()).toMatch /^&nbsp;8/

      editorView.scrollTop(editorView.lineHeight * 3.5)
      expect(editorView.renderedLines.find('.line').length).toBe 10
      expect(editorView.gutter.find('.line-number:first').html()).toMatch /^&nbsp;2/
      expect(editorView.gutter.find('.line-number:last').html()).toMatch /^11/

    it "adds a .foldable class to lines that start foldable regions", ->
      expect(editorView.gutter.find('.line-number:eq(0)')).toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(1)')).toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(2)')).not.toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(3)')).not.toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(4)')).toHaveClass 'foldable'

      # changes to indentation update foldability
      editor.setIndentationForBufferRow(1, 0)
      expect(editorView.gutter.find('.line-number:eq(0)')).not.toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(1)')).toHaveClass 'foldable'

      # changes to comments update foldability
      editor.toggleLineCommentsForBufferRows(2, 3)
      expect(editorView.gutter.find('.line-number:eq(2)')).toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(3)')).not.toHaveClass 'foldable'
      editor.toggleLineCommentForBufferRow(2)
      expect(editorView.gutter.find('.line-number:eq(2)')).not.toHaveClass 'foldable'
      expect(editorView.gutter.find('.line-number:eq(3)')).not.toHaveClass 'foldable'
      editor.toggleLineCommentForBufferRow(4)
      expect(editorView.gutter.find('.line-number:eq(3)')).toHaveClass 'foldable'

    describe "when lines are inserted", ->
      it "re-renders the correct line number range in the gutter", ->
        editorView.scrollTop(3 * editorView.lineHeight)
        expect(editorView.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editorView.gutter.find('.line-number:last').intValue()).toBe 11

        buffer.insert([6, 0], '\n')

        expect(editorView.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editorView.gutter.find('.line-number:last').intValue()).toBe 11

      it "re-renders the correct line number range when there are folds", ->
        editorView.editor.foldBufferRow(1)
        expect(editorView.gutter.find('.line-number-1')).toHaveClass 'folded'

        buffer.insert([0, 0], '\n')

        expect(editorView.gutter.find('.line-number-2')).toHaveClass 'folded'

    describe "when wrapping is on", ->
      it "renders a • instead of line number for wrapped portions of lines", ->
        editor.setSoftWrap(true)
        editorView.setWidthInChars(50)
        expect(editorView.gutter.find('.line-number').length).toEqual(8)
        expect(editorView.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editorView.gutter.find('.line-number:eq(4)').html()).toMatch /^&nbsp;•/
        expect(editorView.gutter.find('.line-number:eq(5)').intValue()).toBe 5

    describe "when there are folds", ->
      it "skips line numbers covered by the fold and updates them when the fold changes", ->
        editor.createFold(3, 5)
        expect(editorView.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editorView.gutter.find('.line-number:eq(4)').intValue()).toBe 7

        buffer.insert([4,0], "\n\n")
        expect(editorView.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editorView.gutter.find('.line-number:eq(4)').intValue()).toBe 9

        buffer.delete([[3,0], [6,0]])
        expect(editorView.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editorView.gutter.find('.line-number:eq(4)').intValue()).toBe 6

      it "redraws gutter numbers when lines are unfolded", ->
        setEditorHeightInLines(editorView, 20)
        fold = editor.createFold(2, 12)
        expect(editorView.gutter.find('.line-number').length).toBe 3

        fold.destroy()
        expect(editorView.gutter.find('.line-number').length).toBe 13

      it "styles folded line numbers", ->
        editor.createFold(3, 5)
        expect(editorView.gutter.find('.line-number.folded').length).toBe 1
        expect(editorView.gutter.find('.line-number.folded:eq(0)').intValue()).toBe 4

    describe "when the scrollView is scrolled to the right", ->
      it "adds a drop shadow to the gutter", ->
        editorView.attachToDom()
        editorView.width(100)

        expect(editorView.gutter).not.toHaveClass('drop-shadow')

        editorView.scrollLeft(10)
        editorView.scrollView.trigger('scroll')

        expect(editorView.gutter).toHaveClass('drop-shadow')

        editorView.scrollLeft(0)
        editorView.scrollView.trigger('scroll')

        expect(editorView.gutter).not.toHaveClass('drop-shadow')

    describe "when the editor view is scrolled vertically", ->
      it "adjusts the padding-top to account for non-rendered line numbers", ->
        editorView.scrollTop(editorView.lineHeight * 3.5)
        expect(editorView.gutter.lineNumbers.css('padding-top')).toBe "#{editorView.lineHeight * 1}px"
        expect(editorView.gutter.lineNumbers.css('padding-bottom')).toBe "#{editorView.lineHeight * 2}px"
        expect(editorView.renderedLines.find('.line').length).toBe 10
        expect(editorView.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editorView.gutter.find('.line-number:last').intValue()).toBe 11

    describe "when the switching from an edit session for a long buffer to an edit session for a short buffer", ->
      it "updates the line numbers to reflect the shorter buffer", ->
        emptyEditor = atom.project.openSync(null)
        editorView.edit(emptyEditor)
        expect(editorView.gutter.lineNumbers.find('.line-number').length).toBe 1

        editorView.edit(editor)
        expect(editorView.gutter.lineNumbers.find('.line-number').length).toBeGreaterThan 1

        editorView.edit(emptyEditor)
        expect(editorView.gutter.lineNumbers.find('.line-number').length).toBe 1

    describe "when the editor view is mini", ->
      it "hides the gutter", ->
        miniEditor = new EditorView(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.gutter).toBeHidden()

      it "doesn't highlight the only line", ->
        miniEditor = new EditorView(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.getEditor().getCursorBufferPosition().row).toBe 0
        expect(miniEditor.find('.line.cursor-line').length).toBe 0

      it "doesn't show the end of line invisible", ->
        atom.config.set "editor.showInvisibles", true
        miniEditor = new EditorView(mini: true)
        miniEditor.attachToDom()
        space = miniEditor.invisibles?.space
        expect(space).toBeTruthy()
        tab = miniEditor.invisibles?.tab
        expect(tab).toBeTruthy()
        miniEditor.getEditor().setText(" a line with tabs\tand spaces ")
        expect(miniEditor.renderedLines.find('.line').text()).toBe "#{space}a line with tabs#{tab} and spaces#{space}"

      it "doesn't show the indent guide", ->
        atom.config.set "editor.showIndentGuide", true
        miniEditor = new EditorView(mini: true)
        miniEditor.attachToDom()
        miniEditor.getEditor().setText("      and indented line")
        expect(miniEditor.renderedLines.find('.indent-guide').length).toBe 0

      it "lets you set the grammar", ->
        miniEditor = new EditorView(mini: true)
        miniEditor.getEditor().setText("var something")
        previousTokens = miniEditor.getEditor().lineForScreenRow(0).tokens
        miniEditor.getEditor().setGrammar(atom.syntax.selectGrammar('something.js'))
        expect(miniEditor.getEditor().getGrammar().name).toBe "JavaScript"
        expect(previousTokens).not.toEqual miniEditor.getEditor().lineForScreenRow(0).tokens

        # doesn't allow regular editors to set grammars
        expect(-> editor.setGrammar()).toThrow()

      describe "placeholderText", ->
        it "is hidden and shown when appropriate", ->
          miniEditor = new EditorView(mini: true, placeholderText: 'octokitten')
          miniEditor.attachToDom()

          expect(miniEditor.underlayer.find('.placeholder-text')).toExist()

          miniEditor.getEditor().setText("var something")
          expect(miniEditor.underlayer.find('.placeholder-text')).not.toExist()

          miniEditor.getEditor().setText("")
          expect(miniEditor.underlayer.find('.placeholder-text')).toExist()

        it "can be set", ->
          miniEditor = new EditorView(mini: true)
          miniEditor.attachToDom()

          expect(miniEditor.find('.placeholder-text').text()).toEqual ''

          miniEditor.setPlaceholderText 'octokitten'
          expect(miniEditor.find('.placeholder-text').text()).toEqual 'octokitten'

          miniEditor.setPlaceholderText 'new one'
          expect(miniEditor.find('.placeholder-text').text()).toEqual 'new one'

    describe "when the editor.showLineNumbers config is false", ->
      it "doesn't render any line numbers", ->
        expect(editorView.gutter.lineNumbers).toBeVisible()
        atom.config.set("editor.showLineNumbers", false)
        expect(editorView.gutter.lineNumbers).not.toBeVisible()

    describe "using gutter's api", ->
      it "can get all the line number elements", ->
        elements = editorView.gutter.getLineNumberElements()
        len = editorView.gutter.lastScreenRow - editorView.gutter.firstScreenRow + 1
        expect(elements).toHaveLength(len)

      it "can get a single line number element", ->
        element = editorView.gutter.getLineNumberElement(3)
        expect(element).toBeTruthy()

      it "returns falsy when there is no line element", ->
        expect(editorView.gutter.getLineNumberElement(42)).toHaveLength 0

      it "can add and remove classes to all the line numbers", ->
        wasAdded = editorView.gutter.addClassToAllLines('heyok')
        expect(wasAdded).toBe true

        elements = editorView.gutter.getLineNumberElementsForClass('heyok')
        expect($(elements)).toHaveClass('heyok')

        editorView.gutter.removeClassFromAllLines('heyok')
        expect($(editorView.gutter.getLineNumberElements())).not.toHaveClass('heyok')

      it "can add and remove classes from a single line number", ->
        wasAdded = editorView.gutter.addClassToLine(3, 'heyok')
        expect(wasAdded).toBe true

        element = editorView.gutter.getLineNumberElement(2)
        expect($(element)).not.toHaveClass('heyok')

      it "can fetch line numbers by their class", ->
        editorView.gutter.addClassToLine(1, 'heyok')
        editorView.gutter.addClassToLine(3, 'heyok')

        elements = editorView.gutter.getLineNumberElementsForClass('heyok')
        expect(elements.length).toBe 2

        expect($(elements[0])).toHaveClass 'line-number-1'
        expect($(elements[0])).toHaveClass 'heyok'

        expect($(elements[1])).toHaveClass 'line-number-3'
        expect($(elements[1])).toHaveClass 'heyok'

  describe "gutter line highlighting", ->
    beforeEach ->
      editorView.attachToDom(heightInLines: 5.5)

    describe "when there is no wrapping", ->
      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 1

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 2

    describe "when there is wrapping", ->
      beforeEach ->
        editorView.attachToDom(30)
        editor.setSoftWrap(true)
        setEditorWidthInChars(editorView, 20)

      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 1

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 2

    describe "when the selection spans multiple lines", ->
      beforeEach ->
        editorView.attachToDom(30)

      it "highlights the foreground of the gutter", ->
        editor.getSelection().setBufferRange([[0,0],[2,2]])
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editorView.find('.line-number.cursor-line').length).toBe 3

      it "doesn't highlight the background of the gutter", ->
        editor.getSelection().setBufferRange([[0,0],[2,0]])
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editorView.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 0

      it "doesn't highlight the last line if it ends at the beginning of a line", ->
        editor.getSelection().setBufferRange([[0,0],[1,0]])
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editorView.find('.line-number.cursor-line').length).toBe 1
        expect(editorView.find('.line-number.cursor-line').intValue()).toBe 1

    it "when a newline is deleted with backspace, the line number of the new cursor position is highlighted", ->
      editor.setCursorScreenPosition([1,0])
      editor.backspace()
      expect(editorView.find('.line-number.cursor-line').length).toBe 1
      expect(editorView.find('.line-number.cursor-line').intValue()).toBe 1

  describe "line highlighting", ->
    beforeEach ->
      editorView.attachToDom(30)

    describe "when there is no wrapping", ->
      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editorView.find('.line.cursor-line').length).toBe 1
        expect(editorView.find('.line.cursor-line').text()).toBe buffer.lineForRow(0)

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editorView.find('.line.cursor-line').length).toBe 1
        expect(editorView.find('.line.cursor-line').text()).toBe buffer.lineForRow(1)

      it "when a newline is deleted with backspace, the line of the new cursor position is highlighted", ->
        editor.setCursorScreenPosition([1,0])
        editor.backspace()
        expect(editorView.find('.line.cursor-line').length).toBe 1

    describe "when there is wrapping", ->
      beforeEach ->
        editor.setSoftWrap(true)
        setEditorWidthInChars(editorView, 20)

      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editorView.find('.line.cursor-line').length).toBe 1
        expect(editorView.find('.line.cursor-line').text()).toBe 'var quicksort = '

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editorView.find('.line.cursor-line').length).toBe 1
        expect(editorView.find('.line.cursor-line').text()).toBe '  var sort = '

    describe "when there is a non-empty selection", ->
      it "does not highlight the line", ->
        editor.setSelectedBufferRange([[1, 0], [1, 1]])
        expect(editorView.find('.line.cursor-line').length).toBe 0

  describe "folding", ->
    beforeEach ->
      editor = atom.project.openSync('two-hundred.txt')
      buffer = editor.buffer
      editorView.edit(editor)
      editorView.attachToDom()

    describe "when a fold-selection event is triggered", ->
      it "folds the lines covered by the selection into a single line with a fold class and marker", ->
        editor.getSelection().setBufferRange([[4,29],[7,4]])
        editorView.trigger 'editor:fold-selection'

        expect(editorView.renderedLines.find('.line:eq(4)')).toHaveClass('fold')
        expect(editorView.renderedLines.find('.line:eq(4) > .fold-marker')).toExist()
        expect(editorView.renderedLines.find('.line:eq(5)').text()).toBe '8'

        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.getCursorScreenPosition()).toEqual [5, 0]

      it "keeps the gutter line and the editor view line the same heights (regression)", ->
        editor.getSelection().setBufferRange([[4,29],[7,4]])
        editorView.trigger 'editor:fold-selection'

        expect(editorView.gutter.find('.line-number:eq(4)').height()).toBe editorView.renderedLines.find('.line:eq(4)').height()

    describe "when a fold placeholder line is clicked", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.setCursorBufferPosition([3,0])
        editor.createFold(3, 5)

        foldLine = editorView.find('.line.fold')
        expect(foldLine).toExist()
        foldLine.mousedown()

        expect(editorView.find('.fold')).not.toExist()
        expect(editorView.find('.fold-marker')).not.toExist()
        expect(editorView.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editorView.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when the unfold-current-row event is triggered when the cursor is on a fold placeholder line", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.setCursorBufferPosition([3,0])
        editorView.trigger 'editor:fold-current-row'

        editor.setCursorBufferPosition([3,0])
        editorView.trigger 'editor:unfold-current-row'

        expect(editorView.find('.fold')).not.toExist()
        expect(editorView.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editorView.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when a selection starts/stops intersecting a fold", ->
      it "adds/removes the 'fold-selected' class to the fold's line element and hides the cursor if it is on the fold line", ->
        editor.createFold(2, 4)

        editor.setSelectedBufferRange([[1, 0], [2, 0]], preserveFolds: true, isReversed: true)
        expect(editorView.lineElementForScreenRow(2)).toMatchSelector('.fold.fold-selected')

        editor.setSelectedBufferRange([[1, 0], [1, 1]], preserveFolds: true)
        expect(editorView.lineElementForScreenRow(2)).not.toMatchSelector('.fold.fold-selected')

        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editorView.lineElementForScreenRow(2)).toMatchSelector('.fold.fold-selected')

        editor.setCursorScreenPosition([3,0])
        expect(editorView.lineElementForScreenRow(2)).not.toMatchSelector('.fold.fold-selected')

        editor.setCursorScreenPosition([2,0])
        expect(editorView.lineElementForScreenRow(2)).toMatchSelector('.fold.fold-selected')
        expect(editorView.find('.cursor')).toBeHidden()

        editor.setCursorScreenPosition([3,0])
        expect(editorView.find('.cursor')).toBeVisible()

    describe "when a selected fold is scrolled into view (and the fold line was not previously rendered)", ->
      it "renders the fold's line element with the 'fold-selected' class", ->
        setEditorHeightInLines(editorView, 5)
        editorView.resetDisplay()

        editor.createFold(2, 4)
        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editorView.renderedLines.find('.fold.fold-selected')).toExist()

        editorView.scrollToBottom()
        expect(editorView.renderedLines.find('.fold.fold-selected')).not.toExist()

        editorView.scrollTop(0)
        expect(editorView.lineElementForScreenRow(2)).toMatchSelector('.fold.fold-selected')

  describe "paging up and down", ->
    beforeEach ->
      editorView.attachToDom()

    it "moves to the last line when page down is repeated from the first line", ->
      rows = editor.getLineCount() - 1
      expect(rows).toBeGreaterThan(0)
      row = editor.getCursor().getScreenPosition().row
      expect(row).toBe(0)
      while row < rows
        editorView.pageDown()
        newRow = editor.getCursor().getScreenPosition().row
        expect(newRow).toBeGreaterThan(row)
        if (newRow <= row)
          break
        row = newRow
      expect(row).toBe(rows)
      expect(editorView.getLastVisibleScreenRow()).toBe(rows)

    it "moves to the first line when page up is repeated from the last line", ->
      editor.moveCursorToBottom()
      row = editor.getCursor().getScreenPosition().row
      expect(row).toBeGreaterThan(0)
      while row > 0
        editorView.pageUp()
        newRow = editor.getCursor().getScreenPosition().row
        expect(newRow).toBeLessThan(row)
        if (newRow >= row)
          break
        row = newRow
      expect(row).toBe(0)
      expect(editorView.getFirstVisibleScreenRow()).toBe(0)

    it "resets to original position when down is followed by up", ->
      expect(editor.getCursor().getScreenPosition().row).toBe(0)
      editorView.pageDown()
      expect(editor.getCursor().getScreenPosition().row).toBeGreaterThan(0)
      editorView.pageUp()
      expect(editor.getCursor().getScreenPosition().row).toBe(0)
      expect(editorView.getFirstVisibleScreenRow()).toBe(0)

  describe ".checkoutHead()", ->
    [filePath, originalPathText] = []

    beforeEach ->
      filePath = atom.project.resolve('git/working-dir/file.txt')
      originalPathText = fs.readFileSync(filePath, 'utf8')
      editor = atom.project.openSync(filePath)
      editorView.edit(editor)

    afterEach ->
      fs.writeFileSync(filePath, originalPathText)

    it "restores the contents of the editor view to the HEAD revision", ->
      editor.setText('')
      editor.save()

      fileChangeHandler = jasmine.createSpy('fileChange')
      editor.getBuffer().file.on 'contents-changed', fileChangeHandler

      editorView.checkoutHead()

      waitsFor "file to trigger contents-changed event", ->
        fileChangeHandler.callCount > 0

      runs ->
        expect(editor.getText()).toBe(originalPathText)

  describe ".pixelPositionForBufferPosition(position)", ->
    describe "when the editor view is detached", ->
      it "returns top and left values of 0", ->
        expect(editorView.isOnDom()).toBeFalsy()
        expect(editorView.pixelPositionForBufferPosition([2,7])).toEqual top: 0, left: 0

    describe "when the editor view is invisible", ->
      it "returns top and left values of 0", ->
        editorView.attachToDom()
        editorView.hide()
        expect(editorView.isVisible()).toBeFalsy()
        expect(editorView.pixelPositionForBufferPosition([2,7])).toEqual top: 0, left: 0

    describe "when the editor view is attached and visible", ->
      beforeEach ->
        editorView.attachToDom()

      it "returns the top and left pixel positions", ->
        expect(editorView.pixelPositionForBufferPosition([2,7])).toEqual top: 40, left: 70

      it "caches the left position", ->
        editorView.renderedLines.css('font-size', '16px')
        expect(editorView.pixelPositionForBufferPosition([2,8])).toEqual top: 40, left: 80

        # make characters smaller
        editorView.renderedLines.css('font-size', '15px')

        expect(editorView.pixelPositionForBufferPosition([2,8])).toEqual top: 40, left: 80

  describe "when clicking in the gutter", ->
    beforeEach ->
      editorView.attachToDom()

    describe "when single clicking", ->
      it "moves the cursor to the start of the selected line", ->
        expect(editor.getCursorScreenPosition()).toEqual [0,0]
        event = $.Event("mousedown")
        event.pageY = editorView.gutter.find(".line-number:eq(1)").offset().top
        event.originalEvent = {detail: 1}
        editorView.gutter.find(".line-number:eq(1)").trigger event
        expect(editor.getCursorScreenPosition()).toEqual [1,0]

    describe "when shift-clicking", ->
      it "selects to the start of the selected line", ->
        expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [0,0]]
        event = $.Event("mousedown")
        event.pageY = editorView.gutter.find(".line-number:eq(1)").offset().top
        event.originalEvent = {detail: 1}
        event.shiftKey = true
        editorView.gutter.find(".line-number:eq(1)").trigger event
        expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [2,0]]

    describe "when mousing down and then moving across multiple lines before mousing up", ->
      describe "when selecting from top to bottom", ->
        it "selects the lines", ->
          mousedownEvent = $.Event("mousedown")
          mousedownEvent.pageY = editorView.gutter.find(".line-number:eq(1)").offset().top
          mousedownEvent.originalEvent = {detail: 1}
          editorView.gutter.find(".line-number:eq(1)").trigger mousedownEvent

          mousemoveEvent = $.Event("mousemove")
          mousemoveEvent.pageY = editorView.gutter.find(".line-number:eq(5)").offset().top
          mousemoveEvent.originalEvent = {detail: 1}
          editorView.gutter.find(".line-number:eq(5)").trigger mousemoveEvent

          $(document).trigger 'mouseup'

          expect(editor.getSelection().getScreenRange()).toEqual [[1,0], [6,0]]

      describe "when selecting from bottom to top", ->
        it "selects the lines", ->
          mousedownEvent = $.Event("mousedown")
          mousedownEvent.pageY = editorView.gutter.find(".line-number:eq(5)").offset().top
          mousedownEvent.originalEvent = {detail: 1}
          editorView.gutter.find(".line-number:eq(5)").trigger mousedownEvent

          mousemoveEvent = $.Event("mousemove")
          mousemoveEvent.pageY = editorView.gutter.find(".line-number:eq(1)").offset().top
          mousemoveEvent.originalEvent = {detail: 1}
          editorView.gutter.find(".line-number:eq(1)").trigger mousemoveEvent

          $(document).trigger 'mouseup'

          expect(editor.getSelection().getScreenRange()).toEqual [[1,0], [6,0]]

  describe "when clicking below the last line", ->
    beforeEach ->
      editorView.attachToDom()

    it "move the cursor to the end of the file", ->
      expect(editor.getCursorScreenPosition()).toEqual [0,0]
      event = mousedownEvent(editorView: editorView, point: [Infinity, 10])
      editorView.underlayer.trigger event
      expect(editor.getCursorScreenPosition()).toEqual [12,2]

    it "selects to the end of the files when shift is pressed", ->
      expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [0,0]]
      event = mousedownEvent(editorView: editorView, point: [Infinity, 10], shiftKey: true)
      editorView.underlayer.trigger event
      expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [12,2]]

  # TODO: Move to editor-spec
  describe ".reloadGrammar()", ->
    [filePath] = []

    beforeEach ->
      tmpdir = fs.absolute(temp.dir)
      filePath = path.join(tmpdir, "grammar-change.txt")
      fs.writeFileSync(filePath, "var i;")

    afterEach ->
      fs.removeSync(filePath) if fs.existsSync(filePath)

    it "updates all the rendered lines when the grammar changes", ->
      editor = atom.project.openSync(filePath)
      editorView.edit(editor)
      expect(editor.getGrammar().name).toBe 'Plain Text'
      atom.syntax.setGrammarOverrideForPath(filePath, 'source.js')
      editor.reloadGrammar()
      expect(editor.getGrammar().name).toBe 'JavaScript'

      tokenizedBuffer = editorView.editor.displayBuffer.tokenizedBuffer
      line0 = tokenizedBuffer.lineForScreenRow(0)
      expect(line0.tokens.length).toBe 3
      expect(line0.tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.modifier.js'])

    it "doesn't update the rendered lines when the grammar doesn't change", ->
      expect(editor.getGrammar().name).toBe 'JavaScript'
      spyOn(editorView, 'updateDisplay').andCallThrough()
      editor.reloadGrammar()
      expect(editor.reloadGrammar()).toBeFalsy()
      expect(editorView.updateDisplay).not.toHaveBeenCalled()
      expect(editor.getGrammar().name).toBe 'JavaScript'

    it "emits an editor:grammar-changed event when updated", ->
      editor = atom.project.openSync(filePath)
      editorView.edit(editor)

      eventHandler = jasmine.createSpy('eventHandler')
      editorView.on('editor:grammar-changed', eventHandler)
      editor.reloadGrammar()

      expect(eventHandler).not.toHaveBeenCalled()

      atom.syntax.setGrammarOverrideForPath(filePath, 'source.js')
      editor.reloadGrammar()
      expect(eventHandler).toHaveBeenCalled()

  describe ".replaceSelectedText()", ->
    it "doesn't call the replace function when the selection is empty", ->
      replaced = false
      edited = false
      replacer = (text) ->
        replaced = true
        'new'

      editor.moveCursorToTop()
      edited = editorView.replaceSelectedText(replacer)
      expect(replaced).toBe false
      expect(edited).toBe false

    it "returns true when transformed text is non-empty", ->
      replaced = false
      edited = false
      replacer = (text) ->
        replaced = true
        'new'

      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      edited = editorView.replaceSelectedText(replacer)
      expect(replaced).toBe true
      expect(edited).toBe true

    it "returns false when transformed text is null", ->
      replaced = false
      edited = false
      replacer = (text) ->
        replaced = true
        null

      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      edited = editorView.replaceSelectedText(replacer)
      expect(replaced).toBe true
      expect(edited).toBe false

    it "returns false when transformed text is undefined", ->
      replaced = false
      edited = false
      replacer = (text) ->
        replaced = true
        undefined

      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      edited = editorView.replaceSelectedText(replacer)
      expect(replaced).toBe true
      expect(edited).toBe false

  describe "when editor:copy-path is triggered", ->
    it "copies the absolute path to the editor view's file to the clipboard", ->
      editorView.trigger 'editor:copy-path'
      expect(atom.clipboard.read()).toBe editor.getPath()

  describe "when editor:move-line-up is triggered", ->
    describe "when there is no selection", ->
      it "moves the line where the cursor is up", ->
        editor.setCursorBufferPosition([1,0])
        editorView.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

      it "moves the cursor to the new row and the same column", ->
        editor.setCursorBufferPosition([1,2])
        editorView.trigger 'editor:move-line-up'
        expect(editor.getCursorBufferPosition()).toEqual [0,2]

      describe "when the line above is folded", ->
        it "moves the line around the fold", ->
          editor.foldBufferRow(1)
          editor.setCursorBufferPosition([10, 0])
          editorView.trigger 'editor:move-line-up'

          expect(editor.getCursorBufferPosition()).toEqual [1, 0]
          expect(buffer.lineForRow(1)).toBe ''
          expect(buffer.lineForRow(2)).toBe '  var sort = function(items) {'
          expect(editor.isFoldedAtBufferRow(1)).toBe false
          expect(editor.isFoldedAtBufferRow(2)).toBe true

        describe "when the line being moved is folded", ->
          it "moves the fold around the fold above it", ->
            editor.setCursorBufferPosition([0, 0])
            editor.insertText """
              var a = function() {
                b = 3;
              };

            """
            editor.foldBufferRow(0)
            editor.foldBufferRow(3)
            editor.setCursorBufferPosition([3, 0])
            editorView.trigger 'editor:move-line-up'

            expect(editor.getCursorBufferPosition()).toEqual [0, 0]
            expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
            expect(buffer.lineForRow(13)).toBe 'var a = function() {'
            editor.logScreenLines()
            expect(editor.isFoldedAtBufferRow(0)).toBe true
            expect(editor.isFoldedAtBufferRow(13)).toBe true

      describe "when the line above is empty and the line above that is folded", ->
        it "moves the line to the empty line", ->
          editor.foldBufferRow(2)
          editor.setCursorBufferPosition([11, 0])
          editorView.trigger 'editor:move-line-up'

          expect(editor.getCursorBufferPosition()).toEqual [10, 0]
          expect(buffer.lineForRow(9)).toBe '  };'
          expect(buffer.lineForRow(10)).toBe '  return sort(Array.apply(this, arguments));'
          expect(buffer.lineForRow(11)).toBe ''
          expect(editor.isFoldedAtBufferRow(2)).toBe true
          expect(editor.isFoldedAtBufferRow(10)).toBe false

    describe "where there is a selection", ->
      describe "when the selection falls inside the line", ->
        it "maintains the selection", ->
          editor.setSelectedBufferRange([[1, 2], [1, 5]])
          expect(editor.getSelectedText()).toBe 'var'
          editorView.trigger 'editor:move-line-up'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 2], [0, 5]]
          expect(editor.getSelectedText()).toBe 'var'

      describe "where there are multiple lines selected", ->
        it "moves the selected lines up", ->
          editor.setSelectedBufferRange([[2, 0], [3, Infinity]])
          editorView.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
          expect(buffer.lineForRow(1)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(2)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(3)).toBe '  var sort = function(items) {'

        it "maintains the selection", ->
          editor.setSelectedBufferRange([[2, 0], [3, 62]])
          editorView.trigger 'editor:move-line-up'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [2, 62]]

      describe "when the last line is selected", ->
        it "moves the selected line up", ->
          editor.setSelectedBufferRange([[12, 0], [12, Infinity]])
          editorView.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(11)).toBe '};'
          expect(buffer.lineForRow(12)).toBe '  return sort(Array.apply(this, arguments));'

      describe "when the last two lines are selected", ->
        it "moves the selected lines up", ->
          editor.setSelectedBufferRange([[11, 0], [12, Infinity]])
          editorView.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(10)).toBe '  return sort(Array.apply(this, arguments));'
          expect(buffer.lineForRow(11)).toBe '};'
          expect(buffer.lineForRow(12)).toBe ''

    describe "when the cursor is on the first line", ->
      it "does not move the line", ->
        editor.setCursorBufferPosition([0,0])
        originalText = editor.getText()
        editorView.trigger 'editor:move-line-up'
        expect(editor.getText()).toBe originalText

    describe "when the cursor is on the trailing newline", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editor.insertNewline()
        editor.moveCursorToBottom()
        originalText = editor.getText()
        editorView.trigger 'editor:move-line-up'
        expect(editor.getText()).toBe originalText

    describe "when the cursor is on a folded line", ->
      it "moves all lines in the fold up and preserves the fold", ->
        editor.setCursorBufferPosition([4, 0])
        editor.foldCurrentRow()
        editorView.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(3)).toBe '    while(items.length > 0) {'
        expect(buffer.lineForRow(7)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
        expect(editor.getSelectedBufferRange()).toEqual [[3, 0], [3, 0]]
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy()

    describe "when the selection contains a folded and unfolded line", ->
      it "moves the selected lines up and preserves the fold", ->
        editor.setCursorBufferPosition([4, 0])
        editor.foldCurrentRow()
        editor.setCursorBufferPosition([3, 4])
        editor.selectDown()
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
        editorView.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(2)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
        expect(buffer.lineForRow(3)).toBe '    while(items.length > 0) {'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 4], [3, 0]]
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy()

    describe "when an entire line is selected including the newline", ->
      it "moves the selected line up", ->
        editor.setCursorBufferPosition([1])
        editor.selectToEndOfLine()
        editor.selectRight()
        editorView.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

  describe "when editor:move-line-down is triggered", ->
    describe "when there is no selection", ->
      it "moves the line where the cursor is down", ->
        editor.setCursorBufferPosition([0, 0])
        editorView.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

      it "moves the cursor to the new row and the same column", ->
        editor.setCursorBufferPosition([0, 2])
        editorView.trigger 'editor:move-line-down'
        expect(editor.getCursorBufferPosition()).toEqual [1, 2]

      describe "when the line below is folded", ->
        it "moves the line around the fold", ->
          editor.setCursorBufferPosition([0, 0])
          editor.foldBufferRow(1)
          editorView.trigger 'editor:move-line-down'

          expect(editor.getCursorBufferPosition()).toEqual [9, 0]
          expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
          expect(buffer.lineForRow(9)).toBe 'var quicksort = function () {'
          expect(editor.isFoldedAtBufferRow(0)).toBe true
          expect(editor.isFoldedAtBufferRow(9)).toBe false

        describe "when the line being moved is folded", ->
          it "moves the fold around the fold below it", ->
            editor.setCursorBufferPosition([0, 0])
            editor.insertText """
              var a = function() {
                b = 3;
              };

            """
            editor.foldBufferRow(0)
            editor.foldBufferRow(3)
            editor.setCursorBufferPosition([0, 0])
            editorView.trigger 'editor:move-line-down'

            expect(editor.getCursorBufferPosition()).toEqual [13, 0]
            expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
            expect(buffer.lineForRow(13)).toBe 'var a = function() {'
            expect(editor.isFoldedAtBufferRow(0)).toBe true
            expect(editor.isFoldedAtBufferRow(13)).toBe true

      describe "when the line below is empty and the line below that is folded", ->
        it "moves the line to the empty line", ->
          editor.setCursorBufferPosition([0, Infinity])
          editor.insertText('\n')
          editor.setCursorBufferPosition([0, 0])
          editor.foldBufferRow(2)
          editorView.trigger 'editor:move-line-down'

          expect(editor.getCursorBufferPosition()).toEqual [1, 0]
          expect(buffer.lineForRow(0)).toBe ''
          expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'
          expect(buffer.lineForRow(2)).toBe '  var sort = function(items) {'
          expect(editor.isFoldedAtBufferRow(0)).toBe false
          expect(editor.isFoldedAtBufferRow(1)).toBe false
          expect(editor.isFoldedAtBufferRow(2)).toBe true

    describe "when the cursor is on the last line", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editorView.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(12)).toBe '};'
        expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 2]]

    describe "when the cursor is on the second to last line", ->
      it "moves the line down", ->
        editor.setCursorBufferPosition([11, 0])
        editorView.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(11)).toBe '};'
        expect(buffer.lineForRow(12)).toBe '  return sort(Array.apply(this, arguments));'
        expect(buffer.lineForRow(13)).toBeUndefined()

    describe "when the cursor is on the second to last line and the last line is empty", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editor.insertNewline()
        editor.setCursorBufferPosition([12, 2])
        editorView.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(12)).toBe '};'
        expect(buffer.lineForRow(13)).toBe ''
        expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 2]]

    describe "where there is a selection", ->
      describe "when the selection falls inside the line", ->
        it "maintains the selection", ->
          editor.setSelectedBufferRange([[1, 2], [1, 5]])
          expect(editor.getSelectedText()).toBe 'var'
          editorView.trigger 'editor:move-line-down'
          expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [2, 5]]
          expect(editor.getSelectedText()).toBe 'var'

      describe "where there are multiple lines selected", ->
        it "moves the selected lines down", ->
          editor.setSelectedBufferRange([[2, 0], [3, Infinity]])
          editorView.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(2)).toBe '    while(items.length > 0) {'
          expect(buffer.lineForRow(3)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(4)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(5)).toBe '      current = items.shift();'

        it "maintains the selection", ->
          editor.setSelectedBufferRange([[2, 0], [3, 62]])
          editorView.trigger 'editor:move-line-down'
          expect(editor.getSelectedBufferRange()).toEqual [[3, 0], [4, 62]]

      describe "when the cursor is on a folded line", ->
        it "moves all lines in the fold down and preserves the fold", ->
          editor.setCursorBufferPosition([4, 0])
          editor.foldCurrentRow()
          editorView.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(4)).toBe '    return sort(left).concat(pivot).concat(sort(right));'
          expect(buffer.lineForRow(5)).toBe '    while(items.length > 0) {'
          expect(editor.getSelectedBufferRange()).toEqual [[5, 0], [5, 0]]
          expect(editor.isFoldedAtScreenRow(5)).toBeTruthy()

      describe "when the selection contains a folded and unfolded line", ->
        it "moves the selected lines down and preserves the fold", ->
          editor.setCursorBufferPosition([4, 0])
          editor.foldCurrentRow()
          editor.setCursorBufferPosition([3, 4])
          editor.selectDown()
          expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
          editorView.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(3)).toBe '    return sort(left).concat(pivot).concat(sort(right));'
          expect(buffer.lineForRow(4)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(5)).toBe '    while(items.length > 0) {'
          expect(editor.getSelectedBufferRange()).toEqual [[4, 4], [5, 0]]
          expect(editor.isFoldedAtScreenRow(5)).toBeTruthy()

      describe "when an entire line is selected including the newline", ->
        it "moves the selected line down", ->
          editor.setCursorBufferPosition([1])
          editor.selectToEndOfLine()
          editor.selectRight()
          editorView.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(1)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(2)).toBe '  var sort = function(items) {'

  describe "when editor:duplicate-line is triggered", ->
    describe "where there is no selection", ->
      describe "when the cursor isn't on a folded line", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.setCursorBufferPosition([0, 5])
          editorView.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
          expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'
          expect(editor.getCursorBufferPosition()).toEqual [1, 5]

      describe "when the cursor is on a folded line", ->
        it "duplicates the entire fold before and moves the cursor to the new fold", ->
          editor.setCursorBufferPosition([4])
          editor.foldCurrentRow()
          editorView.trigger 'editor:duplicate-line'
          expect(editor.getCursorScreenPosition()).toEqual [5]
          expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
          expect(editor.isFoldedAtScreenRow(5)).toBeTruthy()
          expect(buffer.lineForRow(8)).toBe '    while(items.length > 0) {'
          expect(buffer.lineForRow(9)).toBe '      current = items.shift();'
          expect(buffer.lineForRow(10)).toBe '      current < pivot ? left.push(current) : right.push(current);'
          expect(buffer.lineForRow(11)).toBe '    }'

      describe "when the cursor is on the last line and it doesn't have a trailing newline", ->
        it "inserts a newline and the duplicated line", ->
          editor.moveCursorToBottom()
          editorView.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(12)).toBe '};'
          expect(buffer.lineForRow(13)).toBe '};'
          expect(buffer.lineForRow(14)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [13, 2]

      describe "when the cursor in on the last line and it is only a newline", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.moveCursorToBottom()
          editor.insertNewline()
          editor.moveCursorToBottom()
          editorView.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(13)).toBe ''
          expect(buffer.lineForRow(14)).toBe ''
          expect(buffer.lineForRow(15)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [14, 0]

      describe "when the cursor is on the second to last line and the last line only a newline", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.moveCursorToBottom()
          editor.insertNewline()
          editor.setCursorBufferPosition([12])
          editorView.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(12)).toBe '};'
          expect(buffer.lineForRow(13)).toBe '};'
          expect(buffer.lineForRow(14)).toBe ''
          expect(buffer.lineForRow(15)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [13, 0]

  describe "when the escape key is pressed on the editor view", ->
    it "clears multiple selections if there are any, and otherwise allows other bindings to be handled", ->
      atom.keymap.bindKeys 'name', '.editor', {'escape': 'test-event'}
      testEventHandler = jasmine.createSpy("testEventHandler")

      editorView.on 'test-event', testEventHandler
      editorView.editor.addSelectionForBufferRange([[3, 0], [3, 0]])
      expect(editorView.editor.getSelections().length).toBe 2

      editorView.trigger(keydownEvent('escape'))
      expect(editorView.editor.getSelections().length).toBe 1
      expect(testEventHandler).not.toHaveBeenCalled()

      editorView.trigger(keydownEvent('escape'))
      expect(testEventHandler).toHaveBeenCalled()

  describe "when the editor view is attached but invisible", ->
    describe "when the editor view's text is changed", ->
      it "redraws the editor view when it is next shown", ->
        atom.workspaceView = new WorkspaceView
        atom.workspaceView.openSync('sample.js')
        atom.workspaceView.attachToDom()
        editorView = atom.workspaceView.getActiveView()

        view = $$ -> @div id: 'view', tabindex: -1, 'View'
        editorView.getPane().activateItem(view)
        expect(editorView.isVisible()).toBeFalsy()

        editor.setText('hidden changes')
        editor.setCursorBufferPosition([0,4])

        displayUpdatedHandler = jasmine.createSpy("displayUpdatedHandler")
        editorView.on 'editor:display-updated', displayUpdatedHandler
        editorView.getPane().activateItem(editorView.getModel())
        expect(editorView.isVisible()).toBeTruthy()

        waitsFor ->
          displayUpdatedHandler.callCount is 1

        runs ->
          expect(editorView.renderedLines.find('.line').text()).toBe 'hidden changes'

      it "redraws the editor view when it is next reattached", ->
        editorView.attachToDom()
        editorView.hide()
        editor.setText('hidden changes')
        editor.setCursorBufferPosition([0,4])
        editorView.detach()

        displayUpdatedHandler = jasmine.createSpy("displayUpdatedHandler")
        editorView.on 'editor:display-updated', displayUpdatedHandler
        editorView.show()
        editorView.attachToDom()

        waitsFor ->
          displayUpdatedHandler.callCount is 1

        runs ->
          expect(editorView.renderedLines.find('.line').text()).toBe 'hidden changes'

  describe "editor:scroll-to-cursor", ->
    it "scrolls to and centers the editor view on the cursor's position", ->
      editorView.attachToDom(heightInLines: 3)
      editor.setCursorBufferPosition([1, 2])
      editorView.scrollToBottom()
      expect(editorView.getFirstVisibleScreenRow()).not.toBe 0
      expect(editorView.getLastVisibleScreenRow()).not.toBe 2
      editorView.trigger('editor:scroll-to-cursor')
      expect(editorView.getFirstVisibleScreenRow()).toBe 0
      expect(editorView.getLastVisibleScreenRow()).toBe 2

  describe "when the editor view is removed", ->
    it "fires a editor:will-be-removed event", ->
      atom.workspaceView = new WorkspaceView
      atom.workspaceView.openSync('sample.js')
      atom.workspaceView.attachToDom()
      editorView = atom.workspaceView.getActiveView()

      willBeRemovedHandler = jasmine.createSpy('willBeRemovedHandler')
      editorView.on 'editor:will-be-removed', willBeRemovedHandler
      editorView.getPane().destroyActiveItem()
      expect(willBeRemovedHandler).toHaveBeenCalled()

  describe "when setInvisibles is toggled (regression)", ->
    it "renders inserted newlines properly", ->
      editorView.setShowInvisibles(true)
      editor.setCursorBufferPosition([0, 0])
      editorView.attachToDom(heightInLines: 20)
      editorView.setShowInvisibles(false)
      editor.insertText("\n")

      for rowNumber in [1..5]
        expect(editorView.lineElementForScreenRow(rowNumber).text()).toBe buffer.lineForRow(rowNumber)

  describe "when the window is resized", ->
    it "updates the active edit session with the current soft wrap column", ->
      editorView.attachToDom()
      setEditorWidthInChars(editorView, 50)
      expect(editorView.editor.getSoftWrapColumn()).toBe 50
      setEditorWidthInChars(editorView, 100)
      $(window).trigger 'resize'
      expect(editorView.editor.getSoftWrapColumn()).toBe 100

  describe "character width caching", ->
    describe "when soft wrap is enabled", ->
      it "correctly calculates the the position left for a column", ->
        editor.setSoftWrap(true)
        editor.setText('lllll 00000')
        editorView.setFontFamily('serif')
        editorView.setFontSize(10)
        editorView.attachToDom()
        editorView.setWidthInChars(5)

        expect(editorView.pixelPositionForScreenPosition([0, 5]).left).toEqual 15
        expect(editorView.pixelPositionForScreenPosition([1, 5]).left).toEqual 25

        # Check that widths are actually being cached
        spyOn(editorView, 'measureToColumn').andCallThrough()
        editorView.pixelPositionForScreenPosition([0, 5])
        editorView.pixelPositionForScreenPosition([1, 5])
        expect(editorView.measureToColumn.callCount).toBe 0

  describe "when the editor contains hard tabs", ->
    it "correctly calculates the the position left for a column", ->
      editor.setText('\ttest')
      editorView.attachToDom()

      expect(editorView.pixelPositionForScreenPosition([0, editor.getTabLength()]).left).toEqual 20
      expect(editorView.pixelPositionForScreenPosition([0, editor.getTabLength() + 1]).left).toEqual 30

      # Check that widths are actually being cached
      spyOn(editorView, 'measureToColumn').andCallThrough()
      editorView.pixelPositionForScreenPosition([0, editor.getTabLength()])
      editorView.pixelPositionForScreenPosition([0, editor.getTabLength() + 1])
      expect(editorView.measureToColumn.callCount).toBe 0
