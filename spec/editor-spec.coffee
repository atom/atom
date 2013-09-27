{_, $, $$, fs, Editor, Range, RootView} = require 'atom'
path = require 'path'

describe "Editor", ->
  [buffer, editor, editSession, cachedLineHeight, cachedCharWidth] = []

  beforeEach ->
    atom.activatePackage('text-tmbundle', sync: true)
    atom.activatePackage('javascript-tmbundle', sync: true)
    editSession = project.open('sample.js')
    buffer = editSession.buffer
    editor = new Editor(editSession)
    editor.lineOverdraw = 2
    editor.isFocused = true
    editor.enableKeymap()
    editor.attachToDom = ({ heightInLines, widthInChars } = {}) ->
      heightInLines ?= @getBuffer().getLineCount()
      @height(getLineHeight() * heightInLines)
      @width(getCharWidth() * widthInChars) if widthInChars
      $('#jasmine-content').append(this)

  getLineHeight = ->
    return cachedLineHeight if cachedLineHeight?
    calcDimensions()
    cachedLineHeight

  getCharWidth = ->
    return cachedCharWidth if cachedCharWidth?
    calcDimensions()
    cachedCharWidth

  calcDimensions = ->
    editorForMeasurement = new Editor(editSession: project.open('sample.js'))
    editorForMeasurement.attachToDom()
    cachedLineHeight = editorForMeasurement.lineHeight
    cachedCharWidth = editorForMeasurement.charWidth
    editorForMeasurement.remove()

  describe "construction", ->
    it "throws an error if no edit session is given", ->
      expect(-> new Editor).toThrow()

  describe "when the editor is attached to the dom", ->
    it "calculates line height and char width and updates the pixel position of the cursor", ->
      expect(editor.lineHeight).toBeNull()
      expect(editor.charWidth).toBeNull()
      editor.setCursorScreenPosition(row: 2, column: 2)

      editor.attachToDom()

      expect(editor.lineHeight).not.toBeNull()
      expect(editor.charWidth).not.toBeNull()
      expect(editor.find('.cursor').offset()).toEqual pagePixelPositionForPoint(editor, [2, 2])

    it "is focused", ->
      editor.attachToDom()
      expect(editor).toMatchSelector ":has(:focus)"

  describe "when the editor receives focus", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

    it "does not scroll the editor (regression)", ->
      editor.attachToDom(heightInLines: 2)
      editor.selectAll()
      editor.hiddenInput.blur()
      editor.focus()

      expect(editor.hiddenInput).toMatchSelector ':focus'
      expect($(editor[0]).scrollTop()).toBe 0

  describe "when the hidden input is focused / unfocused", ->
    it "assigns the isFocused flag on the editor and also adds/removes the .focused css class", ->
      editor.attachToDom()
      editor.isFocused = false
      editor.hiddenInput.focus()
      expect(editor.isFocused).toBeTruthy()

      editor.hiddenInput.focusout()
      expect(editor.isFocused).toBeFalsy()

  describe "when the activeEditSession's file is modified on disk", ->
    it "triggers an alert", ->
      filePath = "/tmp/atom-changed-file.txt"
      fs.writeSync(filePath, "")
      editSession = project.open(filePath)
      editor.edit(editSession)
      editor.insertText("now the buffer is modified")

      fileChangeHandler = jasmine.createSpy('fileChange')
      editSession.buffer.file.on 'contents-changed', fileChangeHandler

      spyOn(atom, "confirm")

      fs.writeSync(filePath, "a file change")

      waitsFor "file to trigger contents-changed event", ->
        fileChangeHandler.callCount > 0

      runs ->
        expect(atom.confirm).toHaveBeenCalled()

  describe ".remove()", ->
    it "destroys the edit session", ->
      editor.remove()
      expect(editor.activeEditSession.destroyed).toBeTruthy()

  describe ".edit(editSession)", ->
    [newEditSession, newBuffer] = []

    beforeEach ->
      newEditSession = project.open('two-hundred.txt')
      newBuffer = newEditSession.buffer

    it "updates the rendered lines, cursors, selections, scroll position, and event subscriptions to match the given edit session", ->
      editor.attachToDom(heightInLines: 5, widthInChars: 30)
      editor.setCursorBufferPosition([3, 5])
      editor.scrollToBottom()
      editor.scrollLeft(150)
      previousScrollHeight = editor.verticalScrollbar.prop('scrollHeight')
      previousScrollTop = editor.scrollTop()
      previousScrollLeft = editor.scrollLeft()

      newEditSession.setScrollTop(120)
      newEditSession.setSelectedBufferRange([[40, 0], [43, 1]])

      editor.edit(newEditSession)
      { firstRenderedScreenRow, lastRenderedScreenRow } = editor
      expect(editor.lineElementForScreenRow(firstRenderedScreenRow).text()).toBe newBuffer.lineForRow(firstRenderedScreenRow)
      expect(editor.lineElementForScreenRow(lastRenderedScreenRow).text()).toBe newBuffer.lineForRow(editor.lastRenderedScreenRow)
      expect(editor.scrollTop()).toBe 120
      expect(editor.scrollLeft()).toBe 0
      expect(editor.getSelectionView().regions[0].position().top).toBe 40 * editor.lineHeight
      editor.insertText("hello")
      expect(editor.lineElementForScreenRow(40).text()).toBe "hello3"

      editor.edit(editSession)
      { firstRenderedScreenRow, lastRenderedScreenRow } = editor
      expect(editor.lineElementForScreenRow(firstRenderedScreenRow).text()).toBe buffer.lineForRow(firstRenderedScreenRow)
      expect(editor.lineElementForScreenRow(lastRenderedScreenRow).text()).toBe buffer.lineForRow(editor.lastRenderedScreenRow)
      expect(editor.verticalScrollbar.prop('scrollHeight')).toBe previousScrollHeight
      expect(editor.scrollTop()).toBe previousScrollTop
      expect(editor.scrollLeft()).toBe previousScrollLeft
      expect(editor.getCursorView().position()).toEqual { top: 3 * editor.lineHeight, left: 5 * editor.charWidth }
      editor.insertText("goodbye")
      expect(editor.lineElementForScreenRow(3).text()).toMatch /^    vgoodbyear/

    it "triggers alert if edit session's buffer goes into conflict with changes on disk", ->
      filePath = "/tmp/atom-changed-file.txt"
      fs.writeSync(filePath, "")
      tempEditSession = project.open(filePath)
      editor.edit(tempEditSession)
      tempEditSession.insertText("a buffer change")

      spyOn(atom, "confirm")

      contentsConflictedHandler = jasmine.createSpy("contentsConflictedHandler")
      tempEditSession.on 'contents-conflicted', contentsConflictedHandler
      fs.writeSync(filePath, "a file change")
      waitsFor ->
        contentsConflictedHandler.callCount > 0

      runs ->
        expect(atom.confirm).toHaveBeenCalled()

  describe ".scrollTop(n)", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5)
      expect(editor.verticalScrollbar.scrollTop()).toBe 0

    describe "when called with a scroll top argument", ->
      it "sets the scrollTop of the vertical scrollbar and sets scrollTop on the line numbers and lines", ->
        editor.scrollTop(100)
        expect(editor.verticalScrollbar.scrollTop()).toBe 100
        expect(editor.scrollView.scrollTop()).toBe 0
        expect(editor.renderedLines.css('top')).toBe "-100px"
        expect(editor.gutter.lineNumbers.css('top')).toBe "-100px"

        editor.scrollTop(120)
        expect(editor.verticalScrollbar.scrollTop()).toBe 120
        expect(editor.scrollView.scrollTop()).toBe 0
        expect(editor.renderedLines.css('top')).toBe "-120px"
        expect(editor.gutter.lineNumbers.css('top')).toBe "-120px"

      it "does not allow negative scrollTops to be assigned", ->
        editor.scrollTop(-100)
        expect(editor.scrollTop()).toBe 0

      it "doesn't do anything if the scrollTop hasn't changed", ->
        editor.scrollTop(100)
        spyOn(editor.verticalScrollbar, 'scrollTop')
        spyOn(editor.renderedLines, 'css')
        spyOn(editor.gutter.lineNumbers, 'css')

        editor.scrollTop(100)
        expect(editor.verticalScrollbar.scrollTop).not.toHaveBeenCalled()
        expect(editor.renderedLines.css).not.toHaveBeenCalled()
        expect(editor.gutter.lineNumbers.css).not.toHaveBeenCalled()

      describe "when the 'adjustVerticalScrollbar' option is false (defaults to true)", ->
        it "doesn't adjust the scrollTop of the vertical scrollbar", ->
          editor.scrollTop(100, adjustVerticalScrollbar: false)
          expect(editor.verticalScrollbar.scrollTop()).toBe 0
          expect(editor.renderedLines.css('top')).toBe "-100px"
          expect(editor.gutter.lineNumbers.css('top')).toBe "-100px"

    describe "when called with no argument", ->
      it "returns the last assigned value or 0 if none has been assigned", ->
        expect(editor.scrollTop()).toBe 0
        editor.scrollTop(50)
        expect(editor.scrollTop()).toBe 50

    it "sets the new scroll top position on the active edit session", ->
      expect(editor.activeEditSession.getScrollTop()).toBe 0
      editor.scrollTop(123)
      expect(editor.activeEditSession.getScrollTop()).toBe 123

  describe ".scrollHorizontally(pixelPosition)", ->
    it "sets the new scroll left position on the active edit session", ->
      editor.attachToDom(heightInLines: 5)
      setEditorWidthInChars(editor, 5)
      expect(editor.activeEditSession.getScrollLeft()).toBe 0
      editor.scrollHorizontally(left: 50)
      expect(editor.activeEditSession.getScrollLeft()).toBeGreaterThan 0
      expect(editor.activeEditSession.getScrollLeft()).toBe editor.scrollLeft()

  describe "editor:attached event", ->
    it 'only triggers an editor:attached event when it is first added to the DOM', ->
      openHandler = jasmine.createSpy('openHandler')
      editor.on 'editor:attached', openHandler

      editor.attachToDom()
      expect(openHandler).toHaveBeenCalled()
      [event, eventEditor] = openHandler.argsForCall[0]
      expect(eventEditor).toBe editor

      openHandler.reset()
      editor.attachToDom()
      expect(openHandler).not.toHaveBeenCalled()

  describe "editor:path-changed event", ->
    filePath = null

    beforeEach ->
      filePath = "/tmp/something.txt"
      fs.writeSync(filePath, filePath)

    afterEach ->
      fs.remove(filePath) if fs.exists(filePath)

    it "emits event when buffer's path is changed", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor:path-changed', eventHandler
      editor.getBuffer().saveAs(filePath)
      expect(eventHandler).toHaveBeenCalled()

    it "emits event when editor receives a new buffer", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor:path-changed', eventHandler
      editor.edit(project.open(filePath))
      expect(eventHandler).toHaveBeenCalled()

    it "stops listening to events on previously set buffers", ->
      eventHandler = jasmine.createSpy('eventHandler')
      oldBuffer = editor.getBuffer()
      editor.on 'editor:path-changed', eventHandler

      editor.edit(project.open(filePath))
      expect(eventHandler).toHaveBeenCalled()

      eventHandler.reset()
      oldBuffer.saveAs("/tmp/atom-bad.txt")
      expect(eventHandler).not.toHaveBeenCalled()

      eventHandler.reset()
      editor.getBuffer().saveAs("/tmp/atom-new.txt")
      expect(eventHandler).toHaveBeenCalled()

    it "loads the grammar for the new path", ->
      expect(editor.getGrammar().name).toBe 'JavaScript'
      editor.getBuffer().saveAs(filePath)
      expect(editor.getGrammar().name).toBe 'Plain Text'

  describe "font family", ->
    beforeEach ->
      expect(editor.css('font-family')).not.toBe 'Courier'

    it "when there is no config in fontFamily don't set it", ->
      expect($("head style.font-family")).not.toExist()

    describe "when the font family changes", ->
      afterEach ->
        editor.clearFontFamily()

      it "updates the font family of editors and recalculates dimensions critical to cursor positioning", ->
        editor.attachToDom(12)
        lineHeightBefore = editor.lineHeight
        charWidthBefore = editor.charWidth
        editor.setCursorScreenPosition [5, 6]

        config.set("editor.fontFamily", "PCMyungjo")
        expect(editor.css('font-family')).toBe 'PCMyungjo'
        expect($("head style.editor-font-family").text()).toMatch "{font-family: PCMyungjo}"
        expect(editor.charWidth).not.toBe charWidthBefore
        expect(editor.getCursorView().position()).toEqual { top: 5 * editor.lineHeight, left: 6 * editor.charWidth }

        newEditor = new Editor(editor.activeEditSession.copy())
        newEditor.attachToDom()
        expect(newEditor.css('font-family')).toBe 'PCMyungjo'

  describe "font size", ->
    beforeEach ->
      expect(editor.css('font-size')).not.toBe "20px"
      expect(editor.css('font-size')).not.toBe "10px"

    it "sets the initial font size based on the value from config", ->
      expect($("head style.font-size")).toExist()
      expect($("head style.font-size").text()).toMatch "{font-size: #{config.get('editor.fontSize')}px}"

    describe "when the font size changes", ->
      it "updates the font sizes of editors and recalculates dimensions critical to cursor positioning", ->
        config.set("editor.fontSize", 10)
        editor.attachToDom()
        lineHeightBefore = editor.lineHeight
        charWidthBefore = editor.charWidth
        editor.setCursorScreenPosition [5, 6]

        config.set("editor.fontSize", 30)
        expect(editor.css('font-size')).toBe '30px'
        expect(editor.lineHeight).toBeGreaterThan lineHeightBefore
        expect(editor.charWidth).toBeGreaterThan charWidthBefore
        expect(editor.getCursorView().position()).toEqual { top: 5 * editor.lineHeight, left: 6 * editor.charWidth }
        expect(editor.renderedLines.outerHeight()).toBe buffer.getLineCount() * editor.lineHeight
        expect(editor.verticalScrollbarContent.height()).toBe buffer.getLineCount() * editor.lineHeight

        newEditor = new Editor(editor.activeEditSession.copy())
        editor.remove()
        newEditor.attachToDom()
        expect(newEditor.css('font-size')).toBe '30px'

      it "updates the position and size of selection regions", ->
        config.set("editor.fontSize", 10)
        editor.setSelectedBufferRange([[5, 2], [5, 7]])
        editor.attachToDom()

        config.set("editor.fontSize", 30)
        selectionRegion = editor.find('.region')
        expect(selectionRegion.position().top).toBe 5 * editor.lineHeight
        expect(selectionRegion.position().left).toBe 2 * editor.charWidth
        expect(selectionRegion.height()).toBe editor.lineHeight
        expect(selectionRegion.width()).toBe 5 * editor.charWidth

      it "updates lines if there are unrendered lines", ->
        editor.attachToDom(heightInLines: 5)
        originalLineCount = editor.renderedLines.find(".line").length
        expect(originalLineCount).toBeGreaterThan 0

        config.set("editor.fontSize", 10)
        expect(editor.renderedLines.find(".line").length).toBeGreaterThan originalLineCount

      describe "when the font size changes while editor is detached", ->
        it "redraws the editor according to the new font size when it is reattached", ->
          editor.setCursorScreenPosition([4, 2])
          editor.attachToDom()
          initialLineHeight = editor.lineHeight
          initialCharWidth = editor.charWidth
          initialCursorPosition = editor.getCursorView().position()
          initialScrollbarHeight = editor.verticalScrollbarContent.height()
          editor.detach()

          config.set("editor.fontSize", 10)
          expect(editor.lineHeight).toBe initialLineHeight
          expect(editor.charWidth).toBe initialCharWidth

          editor.attachToDom()
          expect(editor.lineHeight).not.toBe initialLineHeight
          expect(editor.charWidth).not.toBe initialCharWidth
          expect(editor.getCursorView().position()).not.toEqual initialCursorPosition
          expect(editor.verticalScrollbarContent.height()).not.toBe initialScrollbarHeight

  describe "mouse events", ->
    beforeEach ->
      editor.attachToDom()
      editor.css(position: 'absolute', top: 10, left: 10, width: 400)

    describe "single-click", ->
      it "re-positions the cursor to the clicked row / column", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 10])
        expect(editor.getCursorScreenPosition()).toEqual(row: 3, column: 10)

      describe "when the lines are scrolled to the right", ->
        it "re-positions the cursor on the clicked location", ->
          setEditorWidthInChars(editor, 30)
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 30]) # scrolls lines to the right
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 50])
          expect(editor.getCursorBufferPosition()).toEqual(row: 3, column: 50)

      describe "when the editor is using a variable-width font", ->
        beforeEach ->
          editor.setFontFamily('sans-serif')

        afterEach ->
          editor.clearFontFamily()

        it "positions the cursor to the clicked row and column", ->
          {top, left} = editor.pixelOffsetForScreenPosition([3, 30])
          editor.renderedLines.trigger mousedownEvent(pageX: left, pageY: top)
          expect(editor.getCursorScreenPosition()).toEqual [3, 30]

    describe "double-click", ->
      it "selects the word under the cursor, and expands the selection wordwise in either direction on a subsequent shift-click", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [8, 24], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [8, 24], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "concat"

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [8, 7], shiftKey: true)
        editor.renderedLines.trigger 'mouseup'

        expect(editor.getSelectedText()).toBe "return sort(left).concat"

      it "stops selecting by word when the selection is emptied", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "quicksort"

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 10])
        editor.renderedLines.trigger 'mouseup'

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 12], originalEvent: {detail: 1}, shiftKey: true)
        expect(editor.getSelectedBufferRange()).toEqual [[3, 10], [3, 12]]

      describe "when clicking between a word and a non-word", ->
        it "selects the word", ->
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 21], originalEvent: {detail: 1})
          editor.renderedLines.trigger 'mouseup'
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 21], originalEvent: {detail: 2})
          editor.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "function"

          editor.setCursorBufferPosition([0, 0])
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 22], originalEvent: {detail: 1})
          editor.renderedLines.trigger 'mouseup'
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 22], originalEvent: {detail: 2})
          editor.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "items"

          editor.setCursorBufferPosition([0, 0])
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 28], originalEvent: {detail: 1})
          editor.renderedLines.trigger 'mouseup'
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 28], originalEvent: {detail: 2})
          editor.renderedLines.trigger 'mouseup'
          expect(editor.getSelectedText()).toBe "{"

    describe "triple/quardruple/etc-click", ->
      it "selects the line under the cursor", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

        # Triple click
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 3})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "  var sort = function(items) {\n"

        # Quad click
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 3})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 4})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "    if (items.length <= 1) return items;\n"

      it "expands the selection linewise in either direction on a subsequent shift-click, but stops selecting linewise once the selection is emptied", ->
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 8], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 8], originalEvent: {detail: 3})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [5, 0]]

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 1}, shiftKey: true)
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [5, 0]]

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().isEmpty()).toBeTruthy()

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 8], originalEvent: {detail: 1}, shiftKey: true)
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [3, 8]]

    describe "shift-click", ->
      it "selects from the cursor's current location to the clicked location", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true)
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "shift-double-click", ->
      it "expands the selection on the first click and ignores the second click", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "shift-triple-click", ->
      it "expands the selection on the first click and ignores the second click", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 3 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "meta-click", ->
      it "places an additional cursor", ->
        editor.attachToDom()
        setEditorHeightInLines(editor, 5)
        editor.setCursorBufferPosition([3, 0])
        editor.scrollTop(editor.lineHeight * 6)

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [6, 0], metaKey: true)
        expect(editor.scrollTop()).toBe editor.lineHeight * (6 - editor.vScrollMargin)

        [cursor1, cursor2] = editor.getCursorViews()
        expect(cursor1.position()).toEqual(top: 3 * editor.lineHeight, left: 0)
        expect(cursor1.getBufferPosition()).toEqual [3, 0]
        expect(cursor2.position()).toEqual(top: 6 * editor.lineHeight, left: 0)
        expect(cursor2.getBufferPosition()).toEqual [6, 0]

    describe "click and drag", ->
      it "creates a selection from the initial click to mouse cursor's location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # start
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 10])

        # moving changes selection
        $(document).trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

      it "selects and scrolls if the mouse is dragged outside of the editor itself", ->
        editor.vScrollMargin = 0
        editor.attachToDom(heightInLines: 5)
        editor.scrollToBottom()

        spyOn(window, 'setInterval').andCallFake ->

        # start
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [12, 0])
        originalScrollTop = editor.scrollTop()

        # moving changes selection
        $(document).trigger mousemoveEvent(editor: editor, pageX: 0, pageY: -1)
        expect(editor.scrollTop()).toBe originalScrollTop - editor.lineHeight

        # every mouse move selects more text
        for x in [0..10]
          $(document).trigger mousemoveEvent(editor: editor, pageX: 0, pageY: -1)

        expect(editor.scrollTop()).toBe 0

      it "ignores non left-click and drags", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        event = mousedownEvent(editor: editor, point: [4, 10])
        event.originalEvent.which = 2
        editor.renderedLines.trigger(event)
        $(document).trigger mousemoveEvent(editor: editor, point: [5, 27])
        $(document).trigger 'mouseup'

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 4, column: 10})

      it "ignores ctrl-click and drags", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        event = mousedownEvent(editor: editor, point: [4, 10])
        event.ctrlKey = true
        editor.renderedLines.trigger(event)
        $(document).trigger mousemoveEvent(editor: editor, point: [5, 27])
        $(document).trigger 'mouseup'

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 4, column: 10})

    describe "double-click and drag", ->
      it "selects the word under the cursor, then continues to select by word in either direction as the mouse is dragged", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 2})
        expect(editor.getSelectedText()).toBe "quicksort"

        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [1, 8])
        expect(editor.getSelectedBufferRange()).toEqual [[0, 4], [1, 10]]
        expect(editor.getCursorBufferPosition()).toEqual [1, 10]

        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [0, 1])
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 13]]
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]

        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 13]]

        # shift-clicking still selects by word, but does not preserve the initial range
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 25], originalEvent: {detail: 1}, shiftKey: true)
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 13], [5, 27]]

    describe "triple-click and drag", ->
      it "expands the initial selection linewise in either direction", ->
        editor.attachToDom()

        # triple click
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 2})
        $(document).trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 3})
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [5, 0]]

        # moving changes selection linewise
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [5, 27])
        expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [6, 0]]
        expect(editor.getCursorBufferPosition()).toEqual [6, 0]

        # moving changes selection linewise
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [2, 27])
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [5, 0]]
        expect(editor.getCursorBufferPosition()).toEqual [2, 0]

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

    describe "meta-click and drag", ->
      it "adds an additional selection", ->
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 10])
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [5, 27])
        editor.renderedLines.trigger 'mouseup'

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [6, 10], metaKey: true)
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [8, 27], metaKey: true)
        editor.renderedLines.trigger 'mouseup'

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[4, 10], [5, 27]]
        expect(selection2.getScreenRange()).toEqual [[6, 10], [8, 27]]

  describe "when text input events are triggered on the hidden input element", ->
    it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
      editor.attachToDom()
      editor.setCursorScreenPosition(row: 1, column: 6)

      expect(buffer.lineForRow(1).charAt(6)).not.toBe 'q'

      editor.hiddenInput.textInput 'q'

      expect(buffer.lineForRow(1).charAt(6)).toBe 'q'
      expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 7)
      expect(editor.renderedLines.find('.line:eq(1)')).toHaveText buffer.lineForRow(1)

  describe "selection rendering", ->
    [charWidth, lineHeight, selection, selectionView] = []

    beforeEach ->
      editor.attachToDom()
      editor.width(500)
      { charWidth, lineHeight } = editor
      selection = editor.getSelection()
      selectionView = editor.getSelectionView()

    describe "when a selection is added", ->
      it "adds a selection view for it with the proper regions", ->
        editor.activeEditSession.addSelectionForBufferRange([[2, 7], [2, 25]])
        selectionViews = editor.getSelectionViews()
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
          selection.setBufferRange(new Range({row: 2, column: 7}, {row: 2, column: 25}))

          expect(selectionView.regions.length).toBe 1
          region = selectionView.regions[0]
          expect(region.position().top).toBeCloseTo(2 * lineHeight)
          expect(region.position().left).toBeCloseTo(7 * charWidth)
          expect(region.height()).toBeCloseTo lineHeight
          expect(region.width()).toBeCloseTo((25 - 7) * charWidth)

      describe "when the selection spans 2 lines", ->
        it "covers the selection's range with 2 regions", ->
          selection.setBufferRange(new Range({row: 2, column: 7}, {row: 3, column: 25}))

          expect(selectionView.regions.length).toBe 2

          region1 = selectionView.regions[0]
          expect(region1.position().top).toBeCloseTo(2 * lineHeight)
          expect(region1.position().left).toBeCloseTo(7 * charWidth)
          expect(region1.height()).toBeCloseTo lineHeight

          expect(region1.width()).toBeCloseTo(editor.renderedLines.outerWidth() - region1.position().left)
          region2 = selectionView.regions[1]
          expect(region2.position().top).toBeCloseTo(3 * lineHeight)
          expect(region2.position().left).toBeCloseTo(0)
          expect(region2.height()).toBeCloseTo lineHeight
          expect(region2.width()).toBeCloseTo(25 * charWidth)

      describe "when the selection spans more than 2 lines", ->
        it "covers the selection's range with 3 regions", ->
          selection.setBufferRange(new Range({row: 2, column: 7}, {row: 6, column: 25}))

          expect(selectionView.regions.length).toBe 3

          region1 = selectionView.regions[0]
          expect(region1.position().top).toBeCloseTo(2 * lineHeight)
          expect(region1.position().left).toBeCloseTo(7 * charWidth)
          expect(region1.height()).toBeCloseTo lineHeight

          expect(region1.width()).toBeCloseTo(editor.renderedLines.outerWidth() - region1.position().left)
          region2 = selectionView.regions[1]
          expect(region2.position().top).toBeCloseTo(3 * lineHeight)
          expect(region2.position().left).toBeCloseTo(0)
          expect(region2.height()).toBeCloseTo(3 * lineHeight)
          expect(region2.width()).toBeCloseTo(editor.renderedLines.outerWidth())

          # resizes with the editor
          expect(editor.width()).toBeLessThan(800)
          editor.width(800)
          expect(region2.width()).toBe(editor.renderedLines.outerWidth())

          region3 = selectionView.regions[2]
          expect(region3.position().top).toBeCloseTo(6 * lineHeight)
          expect(region3.position().left).toBeCloseTo(0)
          expect(region3.height()).toBeCloseTo lineHeight
          expect(region3.width()).toBeCloseTo(25 * charWidth)

      it "clears previously drawn regions before creating new ones", ->
        selection.setBufferRange(new Range({row: 2, column: 7}, {row: 4, column: 25}))
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.region').length).toBe 3

        selectionView.updateDisplay()
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.region').length).toBe 3

    describe "when a selection merges with another selection", ->
      it "removes the merged selection view", ->
        editSession = editor.activeEditSession
        editSession.setCursorScreenPosition([4, 10])
        editSession.selectToScreenPosition([5, 27])
        editSession.addCursorAtScreenPosition([3, 10])
        editSession.selectToScreenPosition([6, 27])

        expect(editor.getSelectionViews().length).toBe 1
        expect(editor.find('.region').length).toBe 3

    describe "when a selection is added and removed before the display is updated", ->
      it "does not attempt to render the selection", ->
        # don't update display until we request it
        jasmine.unspy(editor, 'requestDisplayUpdate')
        spyOn(editor, 'requestDisplayUpdate')

        editSession = editor.activeEditSession
        selection = editSession.addSelectionForBufferRange([[3, 0], [3, 4]])
        selection.destroy()
        editor.updateDisplay()
        expect(editor.getSelectionViews().length).toBe 1

    describe "when the selection is created with the selectAll event", ->
      it "does not scroll to the end of the buffer", ->
        editor.height(150)
        editor.selectAll()
        expect(editor.scrollTop()).toBe 0

        # regression: does not scroll the scroll view when the editor is refocused
        editor.hiddenInput.blur()
        editor.hiddenInput.focus()
        expect(editor.scrollTop()).toBe 0
        expect(editor.scrollView.scrollTop()).toBe 0

        # does autoscroll when the selection is cleared
        editor.moveCursorDown()
        expect(editor.scrollTop()).toBeGreaterThan(0)

    describe "selection autoscrolling and highlighting when setting selected buffer range", ->
      beforeEach ->
        setEditorHeightInLines(editor, 4)

      describe "if autoscroll is true", ->
        it "centers the viewport on the selection if its vertical center is currently offscreen", ->
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editor.scrollTop()).toBe 0

          editor.setSelectedBufferRange([[6, 0], [8, 0]], autoscroll: true)
          expect(editor.scrollTop()).toBe 5 * editor.lineHeight

        it "highlights the selection if autoscroll is true", ->
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editor.getSelectionView()).toHaveClass 'highlighted'
          advanceClock(1000)
          expect(editor.getSelectionView()).not.toHaveClass 'highlighted'

          editor.setSelectedBufferRange([[3, 0], [5, 0]], autoscroll: true)
          expect(editor.getSelectionView()).toHaveClass 'highlighted'

          advanceClock(500)
          spyOn(editor.getSelectionView(), 'removeClass').andCallThrough()
          editor.setSelectedBufferRange([[2, 0], [4, 0]], autoscroll: true)
          expect(editor.getSelectionView().removeClass).toHaveBeenCalledWith('highlighted')
          expect(editor.getSelectionView()).toHaveClass 'highlighted'

          advanceClock(500)
          expect(editor.getSelectionView()).toHaveClass 'highlighted'

      describe "if autoscroll is false", ->
        it "does not scroll to the selection or the cursor", ->
          editor.scrollToBottom()
          scrollTopBefore = editor.scrollTop()
          editor.setSelectedBufferRange([[0, 0], [1, 0]], autoscroll: false)
          expect(editor.scrollTop()).toBe scrollTopBefore

      describe "if autoscroll is not specified", ->
        it "autoscrolls to the cursor as normal", ->
          editor.scrollToBottom()
          editor.setSelectedBufferRange([[0, 0], [1, 0]])
          expect(editor.scrollTop()).toBe 0

  describe "cursor rendering", ->
    describe "when the cursor moves", ->
      charWidth = null

      beforeEach ->
        editor.attachToDom()
        editor.vScrollMargin = 3
        editor.hScrollMargin = 5
        {charWidth} = editor

      it "repositions the cursor's view on screen", ->
        editor.setCursorScreenPosition(row: 2, column: 2)
        expect(editor.getCursorView().position()).toEqual(top: 2 * editor.lineHeight, left: 2 * editor.charWidth)

      it "hides the cursor when the selection is non-empty, and shows it otherwise", ->
        cursorView = editor.getCursorView()
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
        expect(editor.getCursorView().offset()).toEqual(editor.hiddenInput.offset())

      describe "when the editor is using a variable-width font", ->
        beforeEach ->
          editor.setFontFamily('sans-serif')

        afterEach ->
          editor.clearFontFamily()

        it "correctly positions the cursor", ->
          editor.setCursorBufferPosition([3, 30])
          expect(editor.getCursorView().position()).toEqual {top: 3 * editor.lineHeight, left: 178}
          editor.setCursorBufferPosition([3, Infinity])
          expect(editor.getCursorView().position()).toEqual {top: 3 * editor.lineHeight, left: 353}

      describe "autoscrolling", ->
        it "only autoscrolls when the last cursor is moved", ->
          editor.setCursorBufferPosition([11,0])
          editor.addCursorAtBufferPosition([6,50])
          [cursor1, cursor2] = editor.getCursors()

          spyOn(editor, 'scrollToPixelPosition')
          cursor1.setScreenPosition([10, 10])
          expect(editor.scrollToPixelPosition).not.toHaveBeenCalled()

          cursor2.setScreenPosition([11, 11])
          expect(editor.scrollToPixelPosition).toHaveBeenCalled()

        it "does not autoscroll if the 'autoscroll' option is false", ->
          editor.setCursorBufferPosition([11,0])
          spyOn(editor, 'scrollToPixelPosition')
          editor.setCursorScreenPosition([10, 10], autoscroll: false)
          expect(editor.scrollToPixelPosition).not.toHaveBeenCalled()

        it "autoscrolls to cursor if autoscroll is true, even if the position does not change", ->
          spyOn(editor, 'scrollToPixelPosition')
          editor.setCursorScreenPosition([4, 10], autoscroll: false)
          editor.setCursorScreenPosition([4, 10])
          expect(editor.scrollToPixelPosition).toHaveBeenCalled()
          editor.scrollToPixelPosition.reset()

          editor.setCursorBufferPosition([4, 10])
          expect(editor.scrollToPixelPosition).toHaveBeenCalled()

        it "does not autoscroll the cursor based on a buffer change, unless the buffer change was initiated by the cursor", ->
          lastVisibleRow = editor.getLastVisibleScreenRow()
          editor.addCursorAtBufferPosition([lastVisibleRow, 0])
          spyOn(editor, 'scrollToPixelPosition')
          buffer.insert([lastVisibleRow, 0], "\n\n")
          expect(editor.scrollToPixelPosition).not.toHaveBeenCalled()
          editor.insertText('\n\n')
          expect(editor.scrollToPixelPosition.callCount).toBe 1

        describe "when the last cursor exceeds the upper or lower scroll margins", ->
          describe "when the editor is taller than twice the vertical scroll margin", ->
            it "sets the scrollTop so the cursor remains within the scroll margin", ->
              setEditorHeightInLines(editor, 10)

              _.times 6, -> editor.moveCursorDown()
              expect(editor.scrollTop()).toBe(0)

              editor.moveCursorDown()
              expect(editor.scrollTop()).toBe(editor.lineHeight)

              editor.moveCursorDown()
              expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

              _.times 3, -> editor.moveCursorUp()

              editor.moveCursorUp()
              expect(editor.scrollTop()).toBe(editor.lineHeight)

              editor.moveCursorUp()
              expect(editor.scrollTop()).toBe(0)

          describe "when the editor is shorter than twice the vertical scroll margin", ->
            it "sets the scrollTop based on a reduced scroll margin, which prevents a jerky tug-of-war between upper and lower scroll margins", ->
              setEditorHeightInLines(editor, 5)

              _.times 3, -> editor.moveCursorDown()

              expect(editor.scrollTop()).toBe(editor.lineHeight)

              editor.moveCursorUp()
              expect(editor.renderedLines.css('top')).toBe "0px"

        describe "when the last cursor exceeds the right or left scroll margins", ->
          describe "when soft-wrap is disabled", ->
            describe "when the editor is wider than twice the horizontal scroll margin", ->
              it "sets the scrollView's scrollLeft so the cursor remains within the scroll margin", ->
                setEditorWidthInChars(editor, 30)

                # moving right
                editor.setCursorScreenPosition([2, 24])
                expect(editor.scrollLeft()).toBe 0

                editor.setCursorScreenPosition([2, 25])
                expect(editor.scrollLeft()).toBe charWidth

                editor.setCursorScreenPosition([2, 28])
                expect(editor.scrollLeft()).toBe charWidth * 4

                # moving left
                editor.setCursorScreenPosition([2, 9])
                expect(editor.scrollLeft()).toBe charWidth * 4

                editor.setCursorScreenPosition([2, 8])
                expect(editor.scrollLeft()).toBe charWidth * 3

                editor.setCursorScreenPosition([2, 5])
                expect(editor.scrollLeft()).toBe 0

            describe "when the editor is narrower than twice the horizontal scroll margin", ->
              it "sets the scrollView's scrollLeft based on a reduced horizontal scroll margin, to prevent a jerky tug-of-war between right and left scroll margins", ->
                editor.hScrollMargin = 6
                setEditorWidthInChars(editor, 7)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editor.scrollLeft()).toBe(0)

                editor.setCursorScreenPosition([2, 4])
                window.advanceClock()
                expect(editor.scrollLeft()).toBe(charWidth)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editor.scrollLeft()).toBe(0)

          describe "when soft-wrap is enabled", ->
            beforeEach ->
              editSession.setSoftWrap(true)

            it "does not scroll the buffer horizontally", ->
              editor.width(charWidth * 30)

              # moving right
              editor.setCursorScreenPosition([2, 24])
              expect(editor.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 25])
              expect(editor.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 28])
              expect(editor.scrollLeft()).toBe 0

              # moving left
              editor.setCursorScreenPosition([2, 9])
              expect(editor.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 8])
              expect(editor.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 5])
              expect(editor.scrollLeft()).toBe 0

  describe "when editor:toggle-soft-wrap is toggled", ->
    describe "when the text exceeds the editor width and the scroll-view is horizontally scrolled", ->
      it "wraps the text and renders properly", ->
        editor.attachToDom(heightInLines: 30, widthInChars: 30)
        editor.setWidthInChars(100)
        editor.setText("Fashion axe umami jean shorts retro hashtag carles mumblecore. Photo booth skateboard Austin gentrify occupy ethical. Food truck gastropub keffiyeh, squid deep v pinterest literally sustainable salvia scenester messenger bag. Neutra messenger bag flexitarian four loko, shoreditch VHS pop-up tumblr seitan synth master cleanse. Marfa selvage ugh, raw denim authentic try-hard mcsweeney's trust fund fashion axe actually polaroid viral sriracha. Banh mi marfa plaid single-origin coffee. Pickled mumblecore lomo ugh bespoke.")
        editor.scrollLeft(editor.charWidth * 30)
        editor.trigger "editor:toggle-soft-wrap"
        expect(editor.scrollLeft()).toBe 0
        expect(editor.activeEditSession.getSoftWrapColumn()).not.toBe 100

  describe "text rendering", ->
    describe "when all lines in the buffer are visible on screen", ->
      beforeEach ->
        editor.attachToDom()
        expect(editor.trueHeight()).toBeCloseTo buffer.getLineCount() * editor.lineHeight

      it "creates a line element for each line in the buffer with the html-escaped text of the line", ->
        expect(editor.renderedLines.find('.line').length).toEqual(buffer.getLineCount())
        expect(buffer.lineForRow(2)).toContain('<')
        expect(editor.renderedLines.find('.line:eq(2)').html()).toContain '&lt;'

        # renders empty lines with a non breaking space
        expect(buffer.lineForRow(10)).toBe ''
        expect(editor.renderedLines.find('.line:eq(10)').html()).toBe '&nbsp;'

      it "syntax highlights code based on the file type", ->
        line0 = editor.renderedLines.find('.line:first')
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

        line12 = editor.renderedLines.find('.line:eq(11)')
        expect(line12.find('span:eq(2)')).toMatchSelector '.keyword'

      it "wraps hard tabs in a span", ->
        editor.setText('\t<- hard tab')
        line0 = editor.renderedLines.find('.line:first')
        span0_0 = line0.children('span:eq(0)').children('span:eq(0)')
        expect(span0_0).toMatchSelector '.hard-tab'
        expect(span0_0.text()).toBe ' '

      it "wraps leading whitespace in a span", ->
        line1 = editor.renderedLines.find('.line:eq(1)')
        span0_0 = line1.children('span:eq(0)').children('span:eq(0)')
        expect(span0_0).toMatchSelector '.leading-whitespace'
        expect(span0_0.text()).toBe '  '

      it "wraps trailing whitespace in a span", ->
        editor.setText('trailing whitespace ->   ')
        line0 = editor.renderedLines.find('.line:first')
        span0_last = line0.children('span:eq(0)').children('span:last')
        expect(span0_last).toMatchSelector '.trailing-whitespace'
        expect(span0_last.text()).toBe '   '

      describe "when lines are updated in the buffer", ->
        it "syntax highlights the updated lines", ->
          expect(editor.renderedLines.find('.line:eq(0) > span:first > span:first')).toMatchSelector '.storage.modifier.js'
          buffer.insert([0, 0], "q")
          expect(editor.renderedLines.find('.line:eq(0) > span:first > span:first')).not.toMatchSelector '.storage.modifier.js'

          # verify that re-highlighting can occur below the changed line
          buffer.insert([5,0], "/* */")
          buffer.insert([1,0], "/*")
          expect(editor.renderedLines.find('.line:eq(2) > span:first > span:first')).toMatchSelector '.comment'

    describe "when some lines at the end of the buffer are not visible on screen", ->
      beforeEach ->
        editor.attachToDom(heightInLines: 5.5)

      it "only renders the visible lines plus the overdrawn lines, setting the padding-bottom of the lines element to account for the missing lines", ->
        expect(editor.renderedLines.find('.line').length).toBe 8
        expectedPaddingBottom = (buffer.getLineCount() - 8) * editor.lineHeight
        expect(editor.renderedLines.css('padding-bottom')).toBe "#{expectedPaddingBottom}px"
        expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
        expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

      it "renders additional lines when the editor is resized", ->
        setEditorHeightInLines(editor, 10)
        $(window).trigger 'resize'

        expect(editor.renderedLines.find('.line').length).toBe 12
        expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
        expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

      it "renders correctly when scrolling after text is added to the buffer", ->
        editor.insertText("1\n")
        _.times 4, -> editor.moveCursorDown()
        expect(editor.renderedLines.find('.line:eq(2)').text()).toBe editor.lineForBufferRow(2)
        expect(editor.renderedLines.find('.line:eq(7)').text()).toBe editor.lineForBufferRow(7)

      it "renders correctly when scrolling after text is removed from buffer", ->
        editor.getBuffer().delete([[0,0],[1,0]])
        expect(editor.renderedLines.find('.line:eq(0)').text()).toBe editor.lineForBufferRow(0)
        expect(editor.renderedLines.find('.line:eq(5)').text()).toBe editor.lineForBufferRow(5)

        editor.scrollTop(3 * editor.lineHeight)
        expect(editor.renderedLines.find('.line:first').text()).toBe editor.lineForBufferRow(1)
        expect(editor.renderedLines.find('.line:last').text()).toBe editor.lineForBufferRow(10)

      describe "when creating and destroying folds that are longer than the visible lines", ->
        describe "when the cursor precedes the fold when it is destroyed", ->
          it "renders lines and line numbers correctly", ->
            scrollHeightBeforeFold = editor.scrollView.prop('scrollHeight')
            fold = editor.createFold(1, 9)
            fold.destroy()
            expect(editor.scrollView.prop('scrollHeight')).toBe scrollHeightBeforeFold

            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

            expect(editor.gutter.find('.line-number').length).toBe 8
            expect(editor.gutter.find('.line-number:last').intValue()).toBe 8

            editor.scrollTop(4 * editor.lineHeight)
            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

        describe "when the cursor follows the fold when it is destroyed", ->
          it "renders lines and line numbers correctly", ->
            fold = editor.createFold(1, 9)
            editor.setCursorBufferPosition([10, 0])
            fold.destroy()

            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            expect(editor.gutter.find('.line-number').length).toBe 8
            expect(editor.gutter.find('.line-number:last').text()).toBe '13'

            editor.scrollTop(4 * editor.lineHeight)

            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(11)

      describe "when scrolling vertically", ->
        describe "when scrolling less than the editor's height", ->
          it "draws new lines and removes old lines when the last visible line will exceed the last rendered line", ->
            expect(editor.renderedLines.find('.line').length).toBe 8

            editor.scrollTop(editor.lineHeight * 1.5)
            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

            editor.scrollTop(editor.lineHeight * 3.5) # first visible row will be 3, last will be 8
            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editor.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank
            expect(editor.gutter.find('.line-number:first').intValue()).toBe 2
            expect(editor.gutter.find('.line-number:last').intValue()).toBe 11

            # here we don't scroll far enough to trigger additional rendering
            editor.scrollTop(editor.lineHeight * 5.5) # first visible row will be 5, last will be 10
            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editor.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank
            expect(editor.gutter.find('.line-number:first').intValue()).toBe 2
            expect(editor.gutter.find('.line-number:last').intValue()).toBe 11

            editor.scrollTop(editor.lineHeight * 7.5) # first visible row is 7, last will be 12
            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(5)
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            editor.scrollTop(editor.lineHeight * 3.5) # first visible row will be 3, last will be 8
            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editor.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank

            editor.scrollTop(0)
            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

        describe "when scrolling more than the editors height", ->
          it "removes lines that are offscreen and not in range of the overdraw and builds lines that become visible", ->
            editor.scrollTop(editor.layerHeight - editor.scrollView.height())
            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(5)
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(12)

            editor.verticalScrollbar.scrollBottom(0)
            editor.verticalScrollbar.trigger 'scroll'
            expect(editor.renderedLines.find('.line').length).toBe 8
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(0)
            expect(editor.renderedLines.find('.line:last').text()).toBe buffer.lineForRow(7)

        it "adjusts the vertical padding of the lines element to account for non-rendered lines", ->
          editor.scrollTop(editor.lineHeight * 3)
          firstVisibleBufferRow = 3
          expectedPaddingTop = (firstVisibleBufferRow - editor.lineOverdraw) * editor.lineHeight
          expect(editor.renderedLines.css('padding-top')).toBe "#{expectedPaddingTop}px"

          lastVisibleBufferRow = Math.ceil(3 + 5.5) # scroll top in lines + height in lines
          lastOverdrawnRow = lastVisibleBufferRow + editor.lineOverdraw
          expectedPaddingBottom = ((buffer.getLineCount() - lastOverdrawnRow) * editor.lineHeight)
          expect(editor.renderedLines.css('padding-bottom')).toBe "#{expectedPaddingBottom}px"

          editor.scrollToBottom()
          # scrolled to bottom, first visible row is 5 and first rendered row is 3
          firstVisibleBufferRow = Math.floor(buffer.getLineCount() - 5.5)
          firstOverdrawnBufferRow = firstVisibleBufferRow - editor.lineOverdraw
          expectedPaddingTop = firstOverdrawnBufferRow * editor.lineHeight
          expect(editor.renderedLines.css('padding-top')).toBe "#{expectedPaddingTop}px"
          expect(editor.renderedLines.css('padding-bottom')).toBe "0px"

    describe "when lines are added", ->
      beforeEach ->
        editor.attachToDom(heightInLines: 5)

      describe "when the change precedes the first rendered row", ->
        it "inserts and removes rendered lines to account for upstream change", ->
          editor.scrollToBottom()
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[1,0], [3,0]], "1\n2\n3\n")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

      describe "when the change straddles the first rendered row", ->
        it "doesn't render rows that were not previously rendered", ->
          editor.scrollToBottom()

          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[2,0], [7,0]], "2\n3\n4\n5\n6\n7\n8\n9\n")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

      describe "when the change straddles the last rendered row", ->
        it "doesn't render rows that were not previously rendered", ->
          buffer.change([[2,0], [7,0]], "2\n3\n4\n5\n6\n7\n8\n")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the change the follows the last rendered row", ->
        it "does not change the rendered lines", ->
          buffer.change([[12,0], [12,0]], "12\n13\n14\n")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      it "increases the width of the rendered lines element to be either the width of the longest line or the width of the scrollView (whichever is longer)", ->
        maxLineLength = editor.getMaxScreenLineLength()
        setEditorWidthInChars(editor, maxLineLength)
        widthBefore = editor.renderedLines.width()
        expect(widthBefore).toBe editor.scrollView.width() + 20
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editor.renderedLines.width()).toBeGreaterThan widthBefore

    describe "when lines are removed", ->
      beforeEach ->
        editor.attachToDom(heightInLines: 5)

      it "sets the rendered screen line's width to either the max line length or the scollView's width (whichever is greater)", ->
        maxLineLength = editor.getMaxScreenLineLength()
        setEditorWidthInChars(editor, maxLineLength)
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editor.renderedLines.width()).toBeGreaterThan editor.scrollView.width()
        widthBefore = editor.renderedLines.width()
        buffer.delete([[12, 0], [12, Infinity]])
        expect(editor.renderedLines.width()).toBe editor.scrollView.width() + 20

      describe "when the change the precedes the first rendered row", ->
        it "removes rendered lines to account for upstream change", ->
          editor.scrollToBottom()
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[1,0], [2,0]], "")
          expect(editor.renderedLines.find(".line").length).toBe 6
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(11)

      describe "when the change straddles the first rendered row", ->
        it "renders the correct rows", ->
          editor.scrollToBottom()
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[7,0], [11,0]], "1\n2\n")
          expect(editor.renderedLines.find(".line").length).toBe 5
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(10)

      describe "when the change straddles the last rendered row", ->
        it "renders the correct rows", ->
          buffer.change([[2,0], [7,0]], "")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the change the follows the last rendered row", ->
        it "does not change the rendered lines", ->
          buffer.change([[10,0], [12,0]], "")
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(0)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(6)

      describe "when the last line is removed when the editor is scrolled to the bottom", ->
        it "reduces the editor's scrollTop (due to the reduced total scroll height) and renders the correct screen lines", ->
          editor.setCursorScreenPosition([Infinity, Infinity])
          editor.insertText('\n\n\n')
          editor.scrollToBottom()

          expect(buffer.getLineCount()).toBe 16

          initialScrollTop = editor.scrollTop()
          expect(editor.firstRenderedScreenRow).toBe 9
          expect(editor.lastRenderedScreenRow).toBe 15

          editor.backspace()

          expect(editor.scrollTop()).toBeLessThan initialScrollTop
          expect(editor.firstRenderedScreenRow).toBe 9
          expect(editor.lastRenderedScreenRow).toBe 14

          expect(editor.find('.line').length).toBe 6

          editor.backspace()
          expect(editor.firstRenderedScreenRow).toBe 9
          expect(editor.lastRenderedScreenRow).toBe 13

          expect(editor.find('.line').length).toBe 5

          editor.backspace()
          expect(editor.firstRenderedScreenRow).toBe 6
          expect(editor.lastRenderedScreenRow).toBe 12

          expect(editor.find('.line').length).toBe 7

    describe "when folding leaves less then a screen worth of text (regression)", ->
      it "renders lines properly", ->
        editor.lineOverdraw = 1
        editor.attachToDom(heightInLines: 5)
        editor.activeEditSession.foldBufferRow(4)
        editor.activeEditSession.foldBufferRow(0)

        expect(editor.renderedLines.find('.line').length).toBe 1
        expect(editor.renderedLines.find('.line').text()).toBe buffer.lineForRow(0)

    describe "when folding leaves fewer screen lines than the first rendered screen line (regression)", ->
      it "clears all screen lines and does not throw any exceptions", ->
        editor.lineOverdraw = 1
        editor.attachToDom(heightInLines: 5)
        editor.scrollToBottom()
        editor.activeEditSession.foldBufferRow(0)
        expect(editor.renderedLines.find('.line').length).toBe 1
        expect(editor.renderedLines.find('.line').text()).toBe buffer.lineForRow(0)

    describe "when autoscrolling at the end of the document", ->
      it "renders lines properly", ->
        editor.edit(project.open('two-hundred.txt'))
        editor.attachToDom(heightInLines: 5.5)

        expect(editor.renderedLines.find('.line').length).toBe 8

        editor.moveCursorToBottom()

        expect(editor.renderedLines.find('.line').length).toBe 8

    describe "when line has a character that could push it to be too tall (regression)", ->
      it "does renders the line at a consistent height", ->
        editor.attachToDom()
        buffer.insert([0, 0], "–")
        expect(editor.find('.line:eq(0)').outerHeight()).toBe editor.find('.line:eq(1)').outerHeight()

    describe "when config.editor.showInvisibles is set to true", ->
      it "displays spaces, tabs, and newlines using visible non-empty values", ->
        editor.setText " a line with tabs\tand spaces "
        editor.attachToDom()

        expect(config.get("editor.showInvisibles")).toBeFalsy()
        expect(editor.renderedLines.find('.line').text()).toBe " a line with tabs  and spaces "

        config.set("editor.showInvisibles", true)
        space = editor.invisibles?.space
        expect(space).toBeTruthy()
        tab = editor.invisibles?.tab
        expect(tab).toBeTruthy()
        eol = editor.invisibles?.eol
        expect(eol).toBeTruthy()
        expect(editor.renderedLines.find('.line').text()).toBe "#{space}a line with tabs#{tab} and spaces#{space}#{eol}"

        config.set("editor.showInvisibles", false)
        expect(editor.renderedLines.find('.line').text()).toBe " a line with tabs  and spaces "

      it "displays newlines as their own token outside of the other tokens scope", ->
        editor.setShowInvisibles(true)
        editor.attachToDom()
        editor.setText "var"
        expect(editor.find('.line').html()).toBe '<span class="source js"><span class="storage modifier js">var</span></span><span class="invisible-character">¬</span>'

      it "allows invisible glyphs to be customized via config.editor.invisibles", ->
        editor.setText(" \t ")
        editor.attachToDom()
        config.set("editor.showInvisibles", true)
        config.set("editor.invisibles", eol: ";", space: "_", tab: "tab")
        expect(editor.find(".line:first").text()).toBe "_tab _;"

      it "displays trailing carriage return using a visible non-empty value", ->
        editor.setText "a line that ends with a carriage return\r\n"
        editor.attachToDom()

        expect(config.get("editor.showInvisibles")).toBeFalsy()
        expect(editor.renderedLines.find('.line:first').text()).toBe "a line that ends with a carriage return"

        config.set("editor.showInvisibles", true)
        cr = editor.invisibles?.cr
        expect(cr).toBeTruthy()
        eol = editor.invisibles?.eol
        expect(eol).toBeTruthy()
        expect(editor.renderedLines.find('.line:first').text()).toBe "a line that ends with a carriage return#{cr}#{eol}"

      describe "when wrapping is on", ->
        beforeEach ->
          editSession.setSoftWrap(true)

        it "doesn't show the end of line invisible at the end of lines broken due to wrapping", ->
          editor.setText "a line that wraps"
          editor.attachToDom()
          editor.setWidthInChars(6)
          config.set "editor.showInvisibles", true
          space = editor.invisibles?.space
          expect(space).toBeTruthy()
          eol = editor.invisibles?.eol
          expect(eol).toBeTruthy()
          expect(editor.renderedLines.find('.line:first').text()).toBe "a line#{space}"
          expect(editor.renderedLines.find('.line:last').text()).toBe "wraps#{eol}"

        it "displays trailing carriage return using a visible non-empty value", ->
          editor.setText "a line that\r\n"
          editor.attachToDom()
          editor.setWidthInChars(6)
          config.set "editor.showInvisibles", true
          space = editor.invisibles?.space
          expect(space).toBeTruthy()
          cr = editor.invisibles?.cr
          expect(cr).toBeTruthy()
          eol = editor.invisibles?.eol
          expect(eol).toBeTruthy()
          expect(editor.renderedLines.find('.line:first').text()).toBe "a line#{space}"
          expect(editor.renderedLines.find('.line:eq(1)').text()).toBe "that#{cr}#{eol}"
          expect(editor.renderedLines.find('.line:last').text()).toBe "#{eol}"

    describe "when config.editor.showIndentGuide is set to true", ->
      it "adds an indent-guide class to each leading whitespace span", ->
        editor.attachToDom()

        expect(config.get("editor.showIndentGuide")).toBeFalsy()
        config.set("editor.showIndentGuide", true)
        expect(editor.showIndentGuide).toBeTruthy()

        expect(editor.renderedLines.find('.line:eq(0) .indent-guide').length).toBe 0

        expect(editor.renderedLines.find('.line:eq(1) .indent-guide').length).toBe 1
        expect(editor.renderedLines.find('.line:eq(1) .indent-guide').text()).toBe '  '

        expect(editor.renderedLines.find('.line:eq(2) .indent-guide').length).toBe 2
        expect(editor.renderedLines.find('.line:eq(2) .indent-guide').text()).toBe '    '

        expect(editor.renderedLines.find('.line:eq(3) .indent-guide').length).toBe 2
        expect(editor.renderedLines.find('.line:eq(3) .indent-guide').text()).toBe '    '

        expect(editor.renderedLines.find('.line:eq(4) .indent-guide').length).toBe 2
        expect(editor.renderedLines.find('.line:eq(4) .indent-guide').text()).toBe '    '

        expect(editor.renderedLines.find('.line:eq(5) .indent-guide').length).toBe 3
        expect(editor.renderedLines.find('.line:eq(5) .indent-guide').text()).toBe '      '

        expect(editor.renderedLines.find('.line:eq(6) .indent-guide').length).toBe 3
        expect(editor.renderedLines.find('.line:eq(6) .indent-guide').text()).toBe '      '

        expect(editor.renderedLines.find('.line:eq(7) .indent-guide').length).toBe 2
        expect(editor.renderedLines.find('.line:eq(7) .indent-guide').text()).toBe '    '

        expect(editor.renderedLines.find('.line:eq(8) .indent-guide').length).toBe 2
        expect(editor.renderedLines.find('.line:eq(8) .indent-guide').text()).toBe '    '

        expect(editor.renderedLines.find('.line:eq(9) .indent-guide').length).toBe 1
        expect(editor.renderedLines.find('.line:eq(9) .indent-guide').text()).toBe '  '

        expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
        expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

        expect(editor.renderedLines.find('.line:eq(11) .indent-guide').length).toBe 1
        expect(editor.renderedLines.find('.line:eq(11) .indent-guide').text()).toBe '  '

        expect(editor.renderedLines.find('.line:eq(12) .indent-guide').length).toBe 0

      describe "when the indentation level on a line before an empty line is changed", ->
        it "updates the indent guide on the empty line", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

          editor.setCursorBufferPosition([9])
          editor.indentSelectedRows()

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

      describe "when the indentation level on a line after an empty line is changed", ->
        it "updates the indent guide on the empty line", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '  '

          editor.setCursorBufferPosition([11])
          editor.indentSelectedRows()

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

      describe "when a line contains only whitespace", ->
        it "displays an indent guide on the line", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)

          editor.setCursorBufferPosition([10])
          editor.indent()
          editor.indent()
          expect(editor.getCursorBufferPosition()).toEqual [10, 4]
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe '    '

        it "uses the highest indent guide level from the next or previous non-empty line", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)

          editor.setCursorBufferPosition([1, Infinity])
          editor.insertNewline()
          expect(editor.getCursorBufferPosition()).toEqual [2, 0]
          expect(editor.renderedLines.find('.line:eq(2) .indent-guide').length).toBe 2
          expect(editor.renderedLines.find('.line:eq(2) .indent-guide').text()).toBe '    '

      describe "when the line has leading and trailing whitespace", ->
        it "does not display the indent guide in the trailing whitespace", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)

          editor.insertText("/*\n * \n*/")
          expect(editor.renderedLines.find('.line:eq(1) .indent-guide').length).toBe 1
          expect(editor.renderedLines.find('.line:eq(1) .indent-guide')).toHaveClass('leading-whitespace')

      describe "when the line is empty and end of show invisibles are enabled", ->
        it "renders the indent guides interleaved with the end of line invisibles", ->
          editor.attachToDom()
          config.set("editor.showIndentGuide", true)
          config.set("editor.showInvisibles", true)
          eol = editor.invisibles?.eol

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 1
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe "#{eol} "

          editor.setCursorBufferPosition([9])
          editor.indent()

          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').length).toBe 2
          expect(editor.renderedLines.find('.line:eq(10) .indent-guide').text()).toBe "#{eol}   "

  describe "when soft-wrap is enabled", ->
    beforeEach ->
      editSession.setSoftWrap(true)
      editor.attachToDom()
      setEditorHeightInLines(editor, 20)
      setEditorWidthInChars(editor, 50)
      expect(editor.activeEditSession.getSoftWrapColumn()).toBe 50

    it "wraps lines that are too long to fit within the editor's width, adjusting cursor positioning accordingly", ->
      expect(editor.renderedLines.find('.line').length).toBe 16
      expect(editor.renderedLines.find('.line:eq(3)').text()).toBe "    var pivot = items.shift(), current, left = [], "
      expect(editor.renderedLines.find('.line:eq(4)').text()).toBe "right = [];"

      editor.setCursorBufferPosition([3, 51], wrapAtSoftNewlines: true)
      expect(editor.find('.cursor').offset()).toEqual(editor.renderedLines.find('.line:eq(4)').offset())

      editor.setCursorBufferPosition([4, 0])
      expect(editor.find('.cursor').offset()).toEqual(editor.renderedLines.find('.line:eq(5)').offset())

      editor.getSelection().setBufferRange(new Range([6, 30], [6, 55]))
      [region1, region2] = editor.getSelectionView().regions
      expect(region1.offset().top).toBeCloseTo(editor.renderedLines.find('.line:eq(7)').offset().top)
      expect(region2.offset().top).toBeCloseTo(editor.renderedLines.find('.line:eq(8)').offset().top)

    it "handles changes to wrapped lines correctly", ->
      buffer.insert([6, 28], '1234567')
      expect(editor.renderedLines.find('.line:eq(7)').text()).toBe '      current < pivot ? left1234567.push(current) '
      expect(editor.renderedLines.find('.line:eq(8)').text()).toBe ': right.push(current);'
      expect(editor.renderedLines.find('.line:eq(9)').text()).toBe '    }'

    it "changes the max line length and repositions the cursor when the window size changes", ->
      editor.setCursorBufferPosition([3, 60])
      setEditorWidthInChars(editor, 40)
      expect(editor.renderedLines.find('.line').length).toBe 19
      expect(editor.renderedLines.find('.line:eq(4)').text()).toBe "left = [], right = [];"
      expect(editor.renderedLines.find('.line:eq(5)').text()).toBe "    while(items.length > 0) {"
      expect(editor.bufferPositionForScreenPosition(editor.getCursorScreenPosition())).toEqual [3, 60]

    it "does not wrap the lines of any newly assigned buffers", ->
      otherEditSession = project.open()
      otherEditSession.buffer.setText([1..100].join(''))
      editor.edit(otherEditSession)
      expect(editor.renderedLines.find('.line').length).toBe(1)

    it "unwraps lines when softwrap is disabled", ->
      editor.toggleSoftWrap()
      expect(editor.renderedLines.find('.line:eq(3)').text()).toBe '    var pivot = items.shift(), current, left = [], right = [];'

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

    it "calls .setWidthInChars() when the editor is attached because now its dimensions are available to calculate it", ->
      otherEditor = new Editor(editSession: project.open('sample.js'))
      spyOn(otherEditor, 'setWidthInChars')

      otherEditor.activeEditSession.setSoftWrap(true)
      expect(otherEditor.setWidthInChars).not.toHaveBeenCalled()

      otherEditor.simulateDomAttachment()
      expect(otherEditor.setWidthInChars).toHaveBeenCalled()
      otherEditor.remove()

  describe "gutter rendering", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5.5)

    it "creates a line number element for each visible line with &nbsp; padding to the left of the number", ->
      expect(editor.gutter.find('.line-number').length).toBe 8
      expect(editor.find('.line-number:first').html()).toBe "&nbsp;1"
      expect(editor.gutter.find('.line-number:last').html()).toBe "&nbsp;8"

      # here we don't scroll far enough to trigger additional rendering
      editor.scrollTop(editor.lineHeight * 1.5)
      expect(editor.renderedLines.find('.line').length).toBe 8
      expect(editor.gutter.find('.line-number:first').html()).toBe "&nbsp;1"
      expect(editor.gutter.find('.line-number:last').html()).toBe "&nbsp;8"

      editor.scrollTop(editor.lineHeight * 3.5)
      expect(editor.renderedLines.find('.line').length).toBe 10
      expect(editor.gutter.find('.line-number:first').html()).toBe "&nbsp;2"
      expect(editor.gutter.find('.line-number:last').html()).toBe "11"

    describe "when lines are inserted", ->
      it "re-renders the correct line number range in the gutter", ->
        editor.scrollTop(3 * editor.lineHeight)
        expect(editor.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editor.gutter.find('.line-number:last').intValue()).toBe 11

        buffer.insert([6, 0], '\n')

        expect(editor.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editor.gutter.find('.line-number:last').intValue()).toBe 11

    describe "when wrapping is on", ->
      it "renders a • instead of line number for wrapped portions of lines", ->
        editSession.setSoftWrap(true)
        editor.setWidthInChars(50)
        expect(editor.gutter.find('.line-number').length).toEqual(8)
        expect(editor.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editor.gutter.find('.line-number:eq(4)').html()).toBe '&nbsp;•'
        expect(editor.gutter.find('.line-number:eq(5)').intValue()).toBe 5

    describe "when there are folds", ->
      it "skips line numbers covered by the fold and updates them when the fold changes", ->
        editor.createFold(3, 5)
        expect(editor.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editor.gutter.find('.line-number:eq(4)').intValue()).toBe 7

        buffer.insert([4,0], "\n\n")
        expect(editor.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editor.gutter.find('.line-number:eq(4)').intValue()).toBe 9

        buffer.delete([[3,0], [6,0]])
        expect(editor.gutter.find('.line-number:eq(3)').intValue()).toBe 4
        expect(editor.gutter.find('.line-number:eq(4)').intValue()).toBe 6

      it "redraws gutter numbers when lines are unfolded", ->
        setEditorHeightInLines(editor, 20)
        fold = editor.createFold(2, 12)
        expect(editor.gutter.find('.line-number').length).toBe 3

        fold.destroy()
        expect(editor.gutter.find('.line-number').length).toBe 13

      it "styles folded line numbers", ->
        editor.createFold(3, 5)
        expect(editor.gutter.find('.line-number.fold').length).toBe 1
        expect(editor.gutter.find('.line-number.fold:eq(0)').intValue()).toBe 4

    describe "when the scrollView is scrolled to the right", ->
      it "adds a drop shadow to the gutter", ->
        editor.attachToDom()
        editor.width(100)

        expect(editor.gutter).not.toHaveClass('drop-shadow')

        editor.scrollLeft(10)
        editor.scrollView.trigger('scroll')

        expect(editor.gutter).toHaveClass('drop-shadow')

        editor.scrollLeft(0)
        editor.scrollView.trigger('scroll')

        expect(editor.gutter).not.toHaveClass('drop-shadow')

    describe "when the editor is scrolled vertically", ->
      it "adjusts the padding-top to account for non-rendered line numbers", ->
        editor.scrollTop(editor.lineHeight * 3.5)
        expect(editor.gutter.lineNumbers.css('padding-top')).toBe "#{editor.lineHeight * 1}px"
        expect(editor.gutter.lineNumbers.css('padding-bottom')).toBe "#{editor.lineHeight * 2}px"
        expect(editor.renderedLines.find('.line').length).toBe 10
        expect(editor.gutter.find('.line-number:first').intValue()).toBe 2
        expect(editor.gutter.find('.line-number:last').intValue()).toBe 11

    describe "when the switching from an edit session for a long buffer to an edit session for a short buffer", ->
      it "updates the line numbers to reflect the shorter buffer", ->
        emptyEditSession = project.open(null)
        editor.edit(emptyEditSession)
        expect(editor.gutter.lineNumbers.find('.line-number').length).toBe 1

        editor.edit(editSession)
        expect(editor.gutter.lineNumbers.find('.line-number').length).toBeGreaterThan 1

        editor.edit(emptyEditSession)
        expect(editor.gutter.lineNumbers.find('.line-number').length).toBe 1

    describe "when the editor is mini", ->
      it "hides the gutter", ->
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.gutter).toBeHidden()

      it "doesn't highlight the only line", ->
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.getCursorBufferPosition().row).toBe 0
        expect(miniEditor.find('.line.cursor-line').length).toBe 0

      it "doesn't show the end of line invisible", ->
        config.set "editor.showInvisibles", true
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        space = miniEditor.invisibles?.space
        expect(space).toBeTruthy()
        tab = miniEditor.invisibles?.tab
        expect(tab).toBeTruthy()
        miniEditor.setText(" a line with tabs\tand spaces ")
        expect(miniEditor.renderedLines.find('.line').text()).toBe "#{space}a line with tabs#{tab} and spaces#{space}"

      it "doesn't show the indent guide", ->
        config.set "editor.showIndentGuide", true
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        miniEditor.setText("      and indented line")
        expect(miniEditor.renderedLines.find('.indent-guide').length).toBe 0


      it "lets you set the grammar", ->
        miniEditor = new Editor(mini: true)
        miniEditor.setText("var something")
        previousTokens = miniEditor.lineForScreenRow(0).tokens
        miniEditor.setGrammar(syntax.selectGrammar('something.js'))
        expect(miniEditor.getGrammar().name).toBe "JavaScript"
        expect(previousTokens).not.toEqual miniEditor.lineForScreenRow(0).tokens

        # doesn't allow regular editors to set grammars
        expect(-> editor.setGrammar()).toThrow()


    describe "when config.editor.showLineNumbers is false", ->
      it "doesn't render any line numbers", ->
        expect(editor.gutter.lineNumbers).toBeVisible()
        config.set("editor.showLineNumbers", false)
        expect(editor.gutter.lineNumbers).not.toBeVisible()

  describe "gutter line highlighting", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5.5)

    describe "when there is no wrapping", ->
      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 1

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 2

    describe "when there is wrapping", ->
      beforeEach ->
        editor.attachToDom(30)
        editSession.setSoftWrap(true)
        setEditorWidthInChars(editor, 20)

      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 1

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 1
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').intValue()).toBe 2

    describe "when the selection spans multiple lines", ->
      beforeEach ->
        editor.attachToDom(30)

      it "highlights the foreground of the gutter", ->
        editor.getSelection().setBufferRange(new Range([0,0],[2,2]))
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editor.find('.line-number.cursor-line').length).toBe 3

      it "doesn't highlight the background of the gutter", ->
        editor.getSelection().setBufferRange(new Range([0,0],[2,0]))
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editor.find('.line-number.cursor-line.cursor-line-no-selection').length).toBe 0

      it "doesn't highlight the last line if it ends at the beginning of a line", ->
        editor.getSelection().setBufferRange(new Range([0,0],[1,0]))
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editor.find('.line-number.cursor-line').length).toBe 1
        expect(editor.find('.line-number.cursor-line').intValue()).toBe 1

    it "when a newline is deleted with backspace, the line number of the new cursor position is highlighted", ->
      editor.setCursorScreenPosition([1,0])
      editor.backspace()
      expect(editor.find('.line-number.cursor-line').length).toBe 1
      expect(editor.find('.line-number.cursor-line').intValue()).toBe 1

  describe "line highlighting", ->
    beforeEach ->
      editor.attachToDom(30)

    describe "when there is no wrapping", ->
      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line.cursor-line').length).toBe 1
        expect(editor.find('.line.cursor-line').text()).toBe buffer.lineForRow(0)

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line.cursor-line').length).toBe 1
        expect(editor.find('.line.cursor-line').text()).toBe buffer.lineForRow(1)

      it "when a newline is deleted with backspace, the line of the new cursor position is highlighted", ->
        editor.setCursorScreenPosition([1,0])
        editor.backspace()
        expect(editor.find('.line.cursor-line').length).toBe 1

    describe "when there is wrapping", ->
      beforeEach ->
        editSession.setSoftWrap(true)
        setEditorWidthInChars(editor, 20)

      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line.cursor-line').length).toBe 1
        expect(editor.find('.line.cursor-line').text()).toBe 'var quicksort = '

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line.cursor-line').length).toBe 1
        expect(editor.find('.line.cursor-line').text()).toBe '  var sort = '

    describe "when there is a non-empty selection", ->
      it "does not highlight the line", ->
        editor.setSelectedBufferRange([[1, 0], [1, 1]])
        expect(editor.find('.line.cursor-line').length).toBe 0

  describe "folding", ->
    beforeEach ->
      editSession = project.open('two-hundred.txt')
      buffer = editSession.buffer
      editor.edit(editSession)
      editor.attachToDom()

    describe "when a fold-selection event is triggered", ->
      it "folds the lines covered by the selection into a single line with a fold class and marker", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'editor:fold-selection'

        expect(editor.renderedLines.find('.line:eq(4)')).toHaveClass('fold')
        expect(editor.renderedLines.find('.line:eq(4) > .fold-marker')).toExist()
        expect(editor.renderedLines.find('.line:eq(5)').text()).toBe '8'

        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.getCursorScreenPosition()).toEqual [5, 0]

      it "keeps the gutter line and the editor line the same heights (regression)", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'editor:fold-selection'

        expect(editor.gutter.find('.line-number:eq(4)').height()).toBe editor.renderedLines.find('.line:eq(4)').height()

    describe "when a fold placeholder line is clicked", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.setCursorBufferPosition([3,0])
        editSession.createFold(3, 5)

        foldLine = editor.find('.line.fold')
        expect(foldLine).toExist()
        foldLine.mousedown()

        expect(editor.find('.fold')).not.toExist()
        expect(editor.find('.fold-marker')).not.toExist()
        expect(editor.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editor.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when the unfold-current-row event is triggered when the cursor is on a fold placeholder line", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.setCursorBufferPosition([3,0])
        editor.trigger 'editor:fold-current-row'

        editor.setCursorBufferPosition([3,0])
        editor.trigger 'editor:unfold-current-row'

        expect(editor.find('.fold')).not.toExist()
        expect(editor.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editor.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when a selection starts/stops intersecting a fold", ->
      it "adds/removes the 'selected' class to the fold's line element and hides the cursor if it is on the fold line", ->
        editor.createFold(2, 4)

        editor.setSelectedBufferRange([[1, 0], [2, 0]], preserveFolds: true, isReversed: true)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

        editor.setSelectedBufferRange([[1, 0], [1, 1]], preserveFolds: true)
        expect(editor.lineElementForScreenRow(2)).not.toMatchSelector('.fold.selected')

        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

        editor.setCursorScreenPosition([3,0])
        expect(editor.lineElementForScreenRow(2)).not.toMatchSelector('.fold.selected')

        editor.setCursorScreenPosition([2,0])
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')
        expect(editor.find('.cursor')).toBeHidden()

        editor.setCursorScreenPosition([3,0])
        expect(editor.find('.cursor')).toBeVisible()

    describe "when a selected fold is scrolled into view (and the fold line was not previously rendered)", ->
      it "renders the fold's line element with the 'selected' class", ->
        setEditorHeightInLines(editor, 5)
        editor.resetDisplay()

        editor.createFold(2, 4)
        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editor.renderedLines.find('.fold.selected')).toExist()

        editor.scrollToBottom()
        expect(editor.renderedLines.find('.fold.selected')).not.toExist()

        editor.scrollTop(0)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

  describe "paging up and down", ->
    beforeEach ->
      editor.attachToDom()

    it "moves to the last line when page down is repeated from the first line", ->
      rows = editor.getLineCount() - 1
      expect(rows).toBeGreaterThan(0)
      row = editor.getCursor().getScreenPosition().row
      expect(row).toBe(0)
      while row < rows
        editor.pageDown()
        newRow = editor.getCursor().getScreenPosition().row
        expect(newRow).toBeGreaterThan(row)
        if (newRow <= row)
          break
        row = newRow
      expect(row).toBe(rows)
      expect(editor.getLastVisibleScreenRow()).toBe(rows)

    it "moves to the first line when page up is repeated from the last line", ->
      editor.moveCursorToBottom()
      row = editor.getCursor().getScreenPosition().row
      expect(row).toBeGreaterThan(0)
      while row > 0
        editor.pageUp()
        newRow = editor.getCursor().getScreenPosition().row
        expect(newRow).toBeLessThan(row)
        if (newRow >= row)
          break
        row = newRow
      expect(row).toBe(0)
      expect(editor.getFirstVisibleScreenRow()).toBe(0)

    it "resets to original position when down is followed by up", ->
      expect(editor.getCursor().getScreenPosition().row).toBe(0)
      editor.pageDown()
      expect(editor.getCursor().getScreenPosition().row).toBeGreaterThan(0)
      editor.pageUp()
      expect(editor.getCursor().getScreenPosition().row).toBe(0)
      expect(editor.getFirstVisibleScreenRow()).toBe(0)

  describe ".checkoutHead()", ->
    [filePath, originalPathText] = []

    beforeEach ->
      filePath = project.resolve('git/working-dir/file.txt')
      originalPathText = fs.read(filePath)
      editor.edit(project.open(filePath))

    afterEach ->
      fs.writeSync(filePath, originalPathText)

    it "restores the contents of the editor to the HEAD revision", ->
      editor.setText('')
      editor.getBuffer().save()

      fileChangeHandler = jasmine.createSpy('fileChange')
      editor.getBuffer().file.on 'contents-changed', fileChangeHandler

      editor.checkoutHead()

      waitsFor "file to trigger contents-changed event", ->
        fileChangeHandler.callCount > 0

      runs ->
        expect(editor.getText()).toBe(originalPathText)

  describe ".pixelPositionForBufferPosition(position)", ->
    describe "when the editor is detached", ->
      it "returns top and left values of 0", ->
        expect(editor.isOnDom()).toBeFalsy()
        expect(editor.pixelPositionForBufferPosition([2,7])).toEqual top: 0, left: 0

    describe "when the editor is invisible", ->
      it "returns top and left values of 0", ->
        editor.attachToDom()
        editor.hide()
        expect(editor.isVisible()).toBeFalsy()
        expect(editor.pixelPositionForBufferPosition([2,7])).toEqual top: 0, left: 0

    describe "when the editor is attached and visible", ->
      it "returns the top and left pixel positions", ->
        editor.attachToDom()
        expect(editor.pixelPositionForBufferPosition([2,7])).toEqual top: 40, left: 70

  describe "when clicking in the gutter", ->
    beforeEach ->
      editor.attachToDom()

    describe "when single clicking", ->
      it "moves the cursor to the start of the selected line", ->
        expect(editor.getCursorScreenPosition()).toEqual [0,0]
        event = $.Event("mousedown")
        event.pageY = editor.gutter.find(".line-number:eq(1)").offset().top
        event.originalEvent = {detail: 1}
        editor.gutter.find(".line-number:eq(1)").trigger event
        expect(editor.getCursorScreenPosition()).toEqual [1,0]

    describe "when shift-clicking", ->
      it "selects to the start of the selected line", ->
        expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [0,0]]
        event = $.Event("mousedown")
        event.pageY = editor.gutter.find(".line-number:eq(1)").offset().top
        event.originalEvent = {detail: 1}
        event.shiftKey = true
        editor.gutter.find(".line-number:eq(1)").trigger event
        expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [2,0]]

    describe "when mousing down and then moving across multiple lines before mousing up", ->
      describe "when selecting from top to bottom", ->
        it "selects the lines", ->
          mousedownEvent = $.Event("mousedown")
          mousedownEvent.pageY = editor.gutter.find(".line-number:eq(1)").offset().top
          mousedownEvent.originalEvent = {detail: 1}
          editor.gutter.find(".line-number:eq(1)").trigger mousedownEvent

          mousemoveEvent = $.Event("mousemove")
          mousemoveEvent.pageY = editor.gutter.find(".line-number:eq(5)").offset().top
          mousemoveEvent.originalEvent = {detail: 1}
          editor.gutter.find(".line-number:eq(5)").trigger mousemoveEvent

          $(document).trigger 'mouseup'

          expect(editor.getSelection().getScreenRange()).toEqual [[1,0], [6,0]]

      describe "when selecting from bottom to top", ->
        it "selects the lines", ->
          mousedownEvent = $.Event("mousedown")
          mousedownEvent.pageY = editor.gutter.find(".line-number:eq(5)").offset().top
          mousedownEvent.originalEvent = {detail: 1}
          editor.gutter.find(".line-number:eq(5)").trigger mousedownEvent

          mousemoveEvent = $.Event("mousemove")
          mousemoveEvent.pageY = editor.gutter.find(".line-number:eq(1)").offset().top
          mousemoveEvent.originalEvent = {detail: 1}
          editor.gutter.find(".line-number:eq(1)").trigger mousemoveEvent

          $(document).trigger 'mouseup'

          expect(editor.getSelection().getScreenRange()).toEqual [[1,0], [6,0]]

  describe "when clicking below the last line", ->
    beforeEach ->
      editor.attachToDom()

    it "move the cursor to the end of the file", ->
      expect(editor.getCursorScreenPosition()).toEqual [0,0]
      event = mousedownEvent(editor: editor, point: [Infinity, 10])
      editor.underlayer.trigger event
      expect(editor.getCursorScreenPosition()).toEqual [12,2]

    it "selects to the end of the files when shift is pressed", ->
      expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [0,0]]
      event = mousedownEvent(editor: editor, point: [Infinity, 10], shiftKey: true)
      editor.underlayer.trigger event
      expect(editor.getSelection().getScreenRange()).toEqual [[0,0], [12,2]]

  describe ".reloadGrammar()", ->
    [filePath] = []

    beforeEach ->
      filePath = path.join(fs.absolute("/tmp"), "grammar-change.txt")
      fs.writeSync(filePath, "var i;")

    afterEach ->
      fs.remove(filePath) if fs.exists(filePath)

    it "updates all the rendered lines when the grammar changes", ->
      editor.edit(project.open(filePath))
      expect(editor.getGrammar().name).toBe 'Plain Text'
      syntax.setGrammarOverrideForPath(filePath, 'source.js')
      editor.reloadGrammar()
      expect(editor.getGrammar().name).toBe 'JavaScript'

      tokenizedBuffer = editor.activeEditSession.displayBuffer.tokenizedBuffer
      line0 = tokenizedBuffer.lineForScreenRow(0)
      expect(line0.tokens.length).toBe 3
      expect(line0.tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.modifier.js'])

    it "doesn't update the rendered lines when the grammar doesn't change", ->
      expect(editor.getGrammar().name).toBe 'JavaScript'
      spyOn(editor, 'updateDisplay').andCallThrough()
      editor.reloadGrammar()
      expect(editor.reloadGrammar()).toBeFalsy()
      expect(editor.updateDisplay).not.toHaveBeenCalled()
      expect(editor.getGrammar().name).toBe 'JavaScript'

    it "emits an editor:grammar-changed event when updated", ->
      editor.edit(project.open(filePath))

      eventHandler = jasmine.createSpy('eventHandler')
      editor.on('editor:grammar-changed', eventHandler)
      editor.reloadGrammar()

      expect(eventHandler).not.toHaveBeenCalled()

      syntax.setGrammarOverrideForPath(filePath, 'source.js')
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
      edited = editor.replaceSelectedText(replacer)
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
      edited = editor.replaceSelectedText(replacer)
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
      edited = editor.replaceSelectedText(replacer)
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
      edited = editor.replaceSelectedText(replacer)
      expect(replaced).toBe true
      expect(edited).toBe false

  describe "when editor:copy-path is triggered", ->
    it "copies the absolute path to the editor's file to the pasteboard", ->
      editor.trigger 'editor:copy-path'
      expect(pasteboard.read()[0]).toBe editor.getPath()

  describe "when editor:move-line-up is triggered", ->
    describe "when there is no selection", ->
      it "moves the line where the cursor is up", ->
        editor.setCursorBufferPosition([1,0])
        editor.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

      it "moves the cursor to the new row and the same column", ->
        editor.setCursorBufferPosition([1,2])
        editor.trigger 'editor:move-line-up'
        expect(editor.getCursorBufferPosition()).toEqual [0,2]

    describe "where there is a selection", ->
      describe "when the selection falls inside the line", ->
        it "maintains the selection", ->
          editor.setSelectedBufferRange([[1, 2], [1, 5]])
          expect(editor.getSelectedText()).toBe 'var'
          editor.trigger 'editor:move-line-up'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 2], [0, 5]]
          expect(editor.getSelectedText()).toBe 'var'

      describe "where there are multiple lines selected", ->
        it "moves the selected lines up", ->
          editor.setSelectedBufferRange([[2, 0], [3, Infinity]])
          editor.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
          expect(buffer.lineForRow(1)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(2)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(3)).toBe '  var sort = function(items) {'

        it "maintains the selection", ->
          editor.setSelectedBufferRange([[2, 0], [3, 62]])
          editor.trigger 'editor:move-line-up'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [2, 62]]

      describe "when the last line is selected", ->
        it "moves the selected line up", ->
          editor.setSelectedBufferRange([[12, 0], [12, Infinity]])
          editor.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(11)).toBe '};'
          expect(buffer.lineForRow(12)).toBe '  return sort(Array.apply(this, arguments));'

      describe "when the last two lines are selected", ->
        it "moves the selected lines up", ->
          editor.setSelectedBufferRange([[11, 0], [12, Infinity]])
          editor.trigger 'editor:move-line-up'
          expect(buffer.lineForRow(10)).toBe '  return sort(Array.apply(this, arguments));'
          expect(buffer.lineForRow(11)).toBe '};'
          expect(buffer.lineForRow(12)).toBe ''

    describe "when the cursor is on the first line", ->
      it "does not move the line", ->
        editor.setCursorBufferPosition([0,0])
        originalText = editor.getText()
        editor.trigger 'editor:move-line-up'
        expect(editor.getText()).toBe originalText

    describe "when the cursor is on the trailing newline", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editor.insertNewline()
        editor.moveCursorToBottom()
        originalText = editor.getText()
        editor.trigger 'editor:move-line-up'
        expect(editor.getText()).toBe originalText

    describe "when the cursor is on a folded line", ->
      it "moves all lines in the fold up and preserves the fold", ->
        editor.setCursorBufferPosition([4, 0])
        editor.foldCurrentRow()
        editor.trigger 'editor:move-line-up'
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
        editor.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(2)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
        expect(buffer.lineForRow(3)).toBe '    while(items.length > 0) {'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 4], [3, 0]]
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy()

    describe "when an entire line is selected including the newline", ->
      it "moves the selected line up", ->
        editor.setCursorBufferPosition([1])
        editor.selectToEndOfLine()
        editor.selectRight()
        editor.trigger 'editor:move-line-up'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

  describe "when editor:move-line-down is triggered", ->
    describe "when there is no selection", ->
      it "moves the line where the cursor is down", ->
        editor.setCursorBufferPosition([0, 0])
        editor.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(0)).toBe '  var sort = function(items) {'
        expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'

      it "moves the cursor to the new row and the same column", ->
        editor.setCursorBufferPosition([0, 2])
        editor.trigger 'editor:move-line-down'
        expect(editor.getCursorBufferPosition()).toEqual [1, 2]

    describe "when the cursor is on the last line", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editor.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(12)).toBe '};'
        expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 2]]

    describe "when the cursor is on the second to last line", ->
      it "moves the line down", ->
        editor.setCursorBufferPosition([11, 0])
        editor.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(11)).toBe '};'
        expect(buffer.lineForRow(12)).toBe '  return sort(Array.apply(this, arguments));'
        expect(buffer.lineForRow(13)).toBeUndefined()

    describe "when the cursor is on the second to last line and the last line is empty", ->
      it "does not move the line", ->
        editor.moveCursorToBottom()
        editor.insertNewline()
        editor.setCursorBufferPosition([12, 2])
        editor.trigger 'editor:move-line-down'
        expect(buffer.lineForRow(12)).toBe '};'
        expect(buffer.lineForRow(13)).toBe ''
        expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 2]]

    describe "where there is a selection", ->
      describe "when the selection falls inside the line", ->
        it "maintains the selection", ->
          editor.setSelectedBufferRange([[1, 2], [1, 5]])
          expect(editor.getSelectedText()).toBe 'var'
          editor.trigger 'editor:move-line-down'
          expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [2, 5]]
          expect(editor.getSelectedText()).toBe 'var'

      describe "where there are multiple lines selected", ->
        it "moves the selected lines down", ->
          editor.setSelectedBufferRange([[2, 0], [3, Infinity]])
          editor.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(2)).toBe '    while(items.length > 0) {'
          expect(buffer.lineForRow(3)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(4)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(5)).toBe '      current = items.shift();'

        it "maintains the selection", ->
          editor.setSelectedBufferRange([[2, 0], [3, 62]])
          editor.trigger 'editor:move-line-down'
          expect(editor.getSelectedBufferRange()).toEqual [[3, 0], [4, 62]]

      describe "when the cursor is on a folded line", ->
        it "moves all lines in the fold down and preserves the fold", ->
          editor.setCursorBufferPosition([4, 0])
          editor.foldCurrentRow()
          editor.trigger 'editor:move-line-down'
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
          editor.trigger 'editor:move-line-down'
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
          editor.trigger 'editor:move-line-down'
          expect(buffer.lineForRow(1)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(2)).toBe '  var sort = function(items) {'

  describe "when editor:duplicate-line is triggered", ->
    describe "where there is no selection", ->
      describe "when the cursor isn't on a folded line", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.setCursorBufferPosition([0, 5])
          editor.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
          expect(buffer.lineForRow(1)).toBe 'var quicksort = function () {'
          expect(editor.getCursorBufferPosition()).toEqual [1, 5]

      describe "when the cursor is on a folded line", ->
        it "duplicates the entire fold before and moves the cursor to the new fold", ->
          editor.setCursorBufferPosition([4])
          editor.foldCurrentRow()
          editor.trigger 'editor:duplicate-line'
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
          editor.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(12)).toBe '};'
          expect(buffer.lineForRow(13)).toBe '};'
          expect(buffer.lineForRow(14)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [13, 2]

      describe "when the cursor in on the last line and it is only a newline", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.moveCursorToBottom()
          editor.insertNewline()
          editor.moveCursorToBottom()
          editor.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(13)).toBe ''
          expect(buffer.lineForRow(14)).toBe ''
          expect(buffer.lineForRow(15)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [14, 0]

      describe "when the cursor is on the second to last line and the last line only a newline", ->
        it "duplicates the current line below and moves the cursor down one row", ->
          editor.moveCursorToBottom()
          editor.insertNewline()
          editor.setCursorBufferPosition([12])
          editor.trigger 'editor:duplicate-line'
          expect(buffer.lineForRow(12)).toBe '};'
          expect(buffer.lineForRow(13)).toBe '};'
          expect(buffer.lineForRow(14)).toBe ''
          expect(buffer.lineForRow(15)).toBeUndefined()
          expect(editor.getCursorBufferPosition()).toEqual [13, 0]

  describe "editor:save-debug-snapshot", ->
    it "saves the state of the rendered lines, the display buffer, and the buffer to a file of the user's choosing", ->
      saveDialogCallback = null
      spyOn(atom, 'showSaveDialog').andCallFake (callback) -> saveDialogCallback = callback
      spyOn(fs, 'writeSync')

      editor.trigger 'editor:save-debug-snapshot'

      expect(atom.showSaveDialog).toHaveBeenCalled()
      saveDialogCallback('/tmp/state')
      expect(fs.writeSync).toHaveBeenCalled()
      expect(fs.writeSync.argsForCall[0][0]).toBe '/tmp/state'
      expect(typeof fs.writeSync.argsForCall[0][1]).toBe 'string'

  describe "when the escape key is pressed on the editor", ->
    it "clears multiple selections if there are any, and otherwise allows other bindings to be handled", ->
      keymap.bindKeys '.editor', 'escape': 'test-event'
      testEventHandler = jasmine.createSpy("testEventHandler")

      editor.on 'test-event', testEventHandler
      editor.activeEditSession.addSelectionForBufferRange([[3, 0], [3, 0]])
      expect(editor.activeEditSession.getSelections().length).toBe 2

      editor.trigger(keydownEvent('escape'))
      expect(editor.activeEditSession.getSelections().length).toBe 1
      expect(testEventHandler).not.toHaveBeenCalled()

      editor.trigger(keydownEvent('escape'))
      expect(testEventHandler).toHaveBeenCalled()

  describe "when the editor is attached but invisible", ->
    describe "when the editor's text is changed", ->
      it "redraws the editor when it is next shown", ->
        window.rootView = new RootView
        rootView.open('sample.js')
        rootView.attachToDom()
        editor = rootView.getActiveView()

        view = $$ -> @div id: 'view', tabindex: -1, 'View'
        editor.getPane().showItem(view)
        expect(editor.isVisible()).toBeFalsy()

        editor.setText('hidden changes')
        editor.setCursorBufferPosition([0,4])

        displayUpdatedHandler = jasmine.createSpy("displayUpdatedHandler")
        editor.on 'editor:display-updated', displayUpdatedHandler
        editor.getPane().showItem(editor.getModel())
        expect(editor.isVisible()).toBeTruthy()

        waitsFor ->
          displayUpdatedHandler.callCount is 1

        runs ->
          expect(editor.renderedLines.find('.line').text()).toBe 'hidden changes'

      it "redraws the editor when it is next reattached", ->
        editor.attachToDom()
        editor.hide()
        editor.setText('hidden changes')
        editor.setCursorBufferPosition([0,4])
        editor.detach()

        displayUpdatedHandler = jasmine.createSpy("displayUpdatedHandler")
        editor.on 'editor:display-updated', displayUpdatedHandler
        editor.show()
        editor.attachToDom()

        waitsFor ->
          displayUpdatedHandler.callCount is 1

        runs ->
          expect(editor.renderedLines.find('.line').text()).toBe 'hidden changes'

  describe "editor:scroll-to-cursor", ->
    it "scrolls to and centers the editor on the cursor's position", ->
      editor.attachToDom(heightInLines: 3)
      editor.setCursorBufferPosition([1, 2])
      editor.scrollToBottom()
      expect(editor.getFirstVisibleScreenRow()).not.toBe 0
      expect(editor.getLastVisibleScreenRow()).not.toBe 2
      editor.trigger('editor:scroll-to-cursor')
      expect(editor.getFirstVisibleScreenRow()).toBe 0
      expect(editor.getLastVisibleScreenRow()).toBe 2

  describe "when the editor is removed", ->
    it "fires a editor:will-be-removed event", ->
      window.rootView = new RootView
      rootView.open('sample.js')
      rootView.attachToDom()
      editor = rootView.getActiveView()

      willBeRemovedHandler = jasmine.createSpy('fileChange')
      editor.on 'editor:will-be-removed', willBeRemovedHandler
      editor.getPane().destroyActiveItem()
      expect(willBeRemovedHandler).toHaveBeenCalled()

  describe "when setInvisibles is toggled (regression)", ->
    it "renders inserted newlines properly", ->
      editor.setShowInvisibles(true)
      editor.setCursorBufferPosition([0, 0])
      editor.attachToDom(heightInLines: 20)
      editor.setShowInvisibles(false)
      editor.insertText("\n")

      for rowNumber in [1..5]
        expect(editor.lineElementForScreenRow(rowNumber).text()).toBe buffer.lineForRow(rowNumber)

  describe "when the window is resized", ->
    it "updates the active edit session with the current soft wrap column", ->
      editor.attachToDom()
      setEditorWidthInChars(editor, 50)
      expect(editor.activeEditSession.getSoftWrapColumn()).toBe 50
      setEditorWidthInChars(editor, 100)
      $(window).trigger 'resize'
      expect(editor.activeEditSession.getSoftWrapColumn()).toBe 100
