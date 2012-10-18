RootView = require 'root-view'
EditSession = require 'edit-session'
Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'
Project = require 'project'
$ = require 'jquery'
{$$} = require 'space-pen'
_ = require 'underscore'
fs = require 'fs'

describe "Editor", ->
  [rootView, project, buffer, editor, cachedLineHeight] = []

  getLineHeight = ->
    return cachedLineHeight if cachedLineHeight?
    editorForMeasurement = new Editor(editSession: rootView.project.buildEditSessionForPath('sample.js'))
    editorForMeasurement.attachToDom()
    cachedLineHeight = editorForMeasurement.lineHeight
    editorForMeasurement.remove()
    cachedLineHeight

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    project = rootView.project
    editor = rootView.getActiveEditor()
    buffer = editor.getBuffer()

    editor.attachToDom = ({ heightInLines } = {}) ->
      heightInLines ?= this.getBuffer().getLineCount()
      this.height(getLineHeight() * heightInLines)
      $('#jasmine-content').append(this)

    editor.lineOverdraw = 2
    editor.enableKeymap()
    editor.isFocused = true

  afterEach ->
    rootView.remove()

  describe "construction", ->
    it "throws an error if no editor session is given", ->
      expect(-> new Editor).toThrow()

  describe ".copy()", ->
    it "builds a new editor with the same edit sessions, cursor position, and scroll position as the receiver", ->
      rootView.attachToDom()
      rootView.height(8 * editor.lineHeight)
      rootView.width(50 * editor.charWidth)

      editor.edit(rootView.project.buildEditSessionForPath('two-hundred.txt'))
      editor.setCursorScreenPosition([5, 1])
      editor.scrollTop(1.5 * editor.lineHeight)
      editor.scrollView.scrollLeft(44)

      # proves this test covers serialization and deserialization
      spyOn(editor, 'serialize').andCallThrough()
      spyOn(Editor, 'deserialize').andCallThrough()

      newEditor = editor.copy()
      expect(editor.serialize).toHaveBeenCalled()
      expect(Editor.deserialize).toHaveBeenCalled()

      expect(newEditor.getBuffer()).toBe editor.getBuffer()
      expect(newEditor.getCursorScreenPosition()).toEqual editor.getCursorScreenPosition()
      expect(newEditor.editSessions).toEqual(editor.editSessions)
      expect(newEditor.activeEditSession).toEqual(editor.activeEditSession)
      expect(newEditor.getActiveEditSessionIndex()).toEqual(editor.getActiveEditSessionIndex())

      newEditor.height(editor.height())
      newEditor.width(editor.width())
      rootView.remove()
      newEditor.attachToDom()
      expect(newEditor.scrollTop()).toBe editor.scrollTop()
      expect(newEditor.scrollView.scrollLeft()).toBe 44

    it "does not blow up if no file exists for a previous edit session, but prints a warning", ->
      spyOn(console, 'warn')
      fs.write('/tmp/delete-me')
      editor.edit(rootView.project.buildEditSessionForPath('/tmp/delete-me'))
      fs.remove('/tmp/delete-me')
      newEditor = editor.copy()
      expect(console.warn).toHaveBeenCalled()

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

  describe "when the editor recieves focus", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

  describe "when the hidden input is focused / unfocused", ->
    it "assigns the isFocused flag on the editor and also adds/removes the .focused css class", ->
      editor.attachToDom()
      editor.isFocused = false
      editor.hiddenInput.focus()
      expect(editor.isFocused).toBeTruthy()
      expect(editor).toHaveClass('focused')

      editor.hiddenInput.focusout()
      expect(editor.isFocused).toBeFalsy()
      expect(editor).not.toHaveClass('focused')

  describe "when the activeEditSession's file is modified on disk", ->
    it "triggers an alert", ->
      path = "/tmp/atom-changed-file.txt"
      fs.write(path, "")
      editSession = project.buildEditSessionForPath(path)
      editor.edit(editSession)
      editor.insertText("now the buffer is modified")

      fileChangeHandler = jasmine.createSpy('fileChange')
      editSession.buffer.file.on 'contents-change', fileChangeHandler

      spyOn(atom, "confirm")

      fs.write(path, "a file change")

      waitsFor "file to trigger contents-change event", ->
        fileChangeHandler.callCount > 0

      runs ->
        expect(atom.confirm).toHaveBeenCalled()

  describe ".remove()", ->
    it "removes subscriptions from all edit session buffers", ->
      previousEditSession = editor.activeEditSession
      otherEditSession = rootView.project.buildEditSessionForPath(rootView.project.resolve('sample.txt'))
      expect(previousEditSession.buffer.subscriptionCount()).toBeGreaterThan 1

      editor.edit(otherEditSession)
      expect(otherEditSession.buffer.subscriptionCount()).toBeGreaterThan 1

      editor.remove()
      expect(previousEditSession.buffer.subscriptionCount()).toBe 0
      expect(otherEditSession.buffer.subscriptionCount()).toBe 0

  describe "when 'close' is triggered", ->
    it "closes active edit session and loads next edit session", ->
      editor.edit(rootView.project.buildEditSessionForPath())
      editSession = editor.activeEditSession
      spyOn(editSession, 'destroy').andCallThrough()
      spyOn(editor, "remove").andCallThrough()
      editor.trigger "core:close"
      expect(editSession.destroy).toHaveBeenCalled()
      expect(editor.remove).not.toHaveBeenCalled()
      expect(editor.getBuffer()).toBe buffer

    it "calls remove on the editor if there is one edit session and mini is false", ->
      editSession = editor.activeEditSession
      expect(editor.mini).toBeFalsy()
      expect(editor.editSessions.length).toBe 1
      spyOn(editor, 'remove').andCallThrough()
      editor.trigger 'core:close'
      spyOn(editSession, 'destroy').andCallThrough()
      expect(editor.remove).toHaveBeenCalled()

      miniEditor = new Editor(mini: true)
      spyOn(miniEditor, 'remove').andCallThrough()
      miniEditor.trigger 'core:close'
      expect(miniEditor.remove).not.toHaveBeenCalled()

    describe "when buffer is modified", ->
      it "triggers an alert and does not close the session", ->
        spyOn(editor, 'remove').andCallThrough()
        spyOn(atom, 'confirm')
        editor.insertText("I AM CHANGED!")
        editor.trigger "core:close"
        expect(editor.remove).not.toHaveBeenCalled()
        expect(atom.confirm).toHaveBeenCalled()

  describe ".edit(editSession)", ->
    otherEditSession = null

    beforeEach ->
      otherEditSession = rootView.project.buildEditSessionForPath()

    describe "when the edit session wasn't previously assigned to this editor", ->
      it "adds edit session to editor", ->
        originalEditSessionCount = editor.editSessions.length
        editor.edit(otherEditSession)
        expect(editor.activeEditSession).toBe otherEditSession
        expect(editor.editSessions.length).toBe originalEditSessionCount + 1

    describe "when the edit session was previously assigned to this editor", ->
      it "restores the previous edit session associated with the editor", ->
        previousEditSession = editor.activeEditSession

        editor.edit(otherEditSession)
        expect(editor.activeEditSession).not.toBe previousEditSession

        editor.edit(previousEditSession)
        expect(editor.activeEditSession).toBe previousEditSession

    it "handles buffer manipulation correctly after switching to a new edit session", ->
      editor.attachToDom()
      editor.insertText("abc\n")
      expect(editor.lineElementForScreenRow(0).text()).toBe 'abc'

      editor.edit(otherEditSession)
      expect(editor.lineElementForScreenRow(0).html()).toBe '&nbsp;'

      editor.insertText("def\n")
      expect(editor.lineElementForScreenRow(0).text()).toBe 'def'

  describe "switching edit sessions", ->
    [session0, session1, session2] = []

    beforeEach ->
      session0 = editor.activeEditSession

      editor.edit(rootView.project.buildEditSessionForPath('sample.txt'))
      session1 = editor.activeEditSession

      editor.edit(rootView.project.buildEditSessionForPath('two-hundred.txt'))
      session2 = editor.activeEditSession

    describe ".setActiveEditSessionIndex(index)", ->
      it "restores the buffer, cursors, selections, and scroll position of the edit session associated with the index", ->
        editor.attachToDom(heightInLines: 10)
        editor.setSelectedBufferRange([[40, 0], [43, 1]])
        expect(editor.getSelection().getScreenRange()).toEqual [[40, 0], [43, 1]]
        previousScrollHeight = editor.verticalScrollbar.prop('scrollHeight')
        editor.scrollTop(750)
        expect(editor.scrollTop()).toBe 750

        editor.setActiveEditSessionIndex(0)
        expect(editor.getBuffer()).toBe session0.buffer

        editor.setActiveEditSessionIndex(2)
        expect(editor.getBuffer()).toBe session2.buffer
        expect(editor.getCursorScreenPosition()).toEqual [43, 1]
        expect(editor.verticalScrollbar.prop('scrollHeight')).toBe previousScrollHeight
        expect(editor.scrollTop()).toBe 750
        expect(editor.getSelection().getScreenRange()).toEqual [[40, 0], [43, 1]]
        expect(editor.getSelectionView().find('.selection')).toExist()

        editor.setActiveEditSessionIndex(0)
        editor.activeEditSession.selectToEndOfLine()
        expect(editor.getSelectionView().find('.selection')).toExist()

      it "triggers alert if edit session's file changed on disk", ->
        path = "/tmp/atom-changed-file.txt"
        fs.write(path, "")
        editSession = project.buildEditSessionForPath(path)
        editor.edit editSession
        editSession.insertText("a buffer change")

        bufferContentsChangeHandler = jasmine.createSpy('fileChange')
        editSession.on 'buffer-contents-change-on-disk', bufferContentsChangeHandler

        spyOn(atom, "confirm")

        fs.write(path, "a file change")

        waitsFor "file to trigger contents-change event", ->
          bufferContentsChangeHandler.callCount > 0

        runs ->
          expect(atom.confirm).toHaveBeenCalled()

    describe ".loadNextEditSession()", ->
      it "loads the next editor state and wraps to beginning when end is reached", ->
        expect(editor.activeEditSession).toBe session2
        editor.loadNextEditSession()
        expect(editor.activeEditSession).toBe session0
        editor.loadNextEditSession()
        expect(editor.activeEditSession).toBe session1
        editor.loadNextEditSession()
        expect(editor.activeEditSession).toBe session2

    describe ".loadPreviousEditSession()", ->
      it "loads the next editor state and wraps to beginning when end is reached", ->
        expect(editor.activeEditSession).toBe session2
        editor.loadPreviousEditSession()
        expect(editor.activeEditSession).toBe session1
        editor.loadPreviousEditSession()
        expect(editor.activeEditSession).toBe session0
        editor.loadPreviousEditSession()
        expect(editor.activeEditSession).toBe session2

  describe ".save()", ->
    describe "when the current buffer has a path", ->
      tempFilePath = null

      beforeEach ->
        rootView.remove()

        tempFilePath = '/tmp/atom-temp.txt'
        fs.write(tempFilePath, "")
        rootView = new RootView(tempFilePath)
        editor = rootView.getActiveEditor()
        project = rootView.project

        expect(editor.getPath()).toBe tempFilePath

      afterEach ->
        expect(fs.remove(tempFilePath))

      it "saves the current buffer to disk", ->
        editor.getBuffer().setText 'Edited!'
        expect(fs.read(tempFilePath)).not.toBe "Edited!"

        editor.save()

        expect(fs.exists(tempFilePath)).toBeTruthy()
        expect(fs.read(tempFilePath)).toBe 'Edited!'

    describe "when the current buffer has no path", ->
      selectedFilePath = null
      beforeEach ->
        editor.edit(rootView.project.buildEditSessionForPath())

        expect(editor.getPath()).toBeUndefined()
        editor.getBuffer().setText 'Save me to a new path'
        spyOn(atom, 'showSaveDialog').andCallFake (callback) -> callback(selectedFilePath)

      it "presents a 'save as' dialog", ->
        editor.save()
        expect(atom.showSaveDialog).toHaveBeenCalled()

      describe "when a path is chosen", ->
        it "saves the buffer to the chosen path", ->
          selectedFilePath = '/tmp/temp.txt'

          editor.save()

          expect(fs.exists(selectedFilePath)).toBeTruthy()
          expect(fs.read(selectedFilePath)).toBe 'Save me to a new path'

      describe "when dialog is cancelled", ->
        it "does not save the buffer", ->
          selectedFilePath = null
          editor.save()
          expect(fs.exists(selectedFilePath)).toBeFalsy()

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

  describe "split methods", ->
    describe "when inside a pane", ->
      fakePane = null
      beforeEach ->
        fakePane = { splitUp: jasmine.createSpy('splitUp').andReturn({}), remove: -> }
        spyOn(editor, 'pane').andReturn(fakePane)

      it "calls the corresponding split method on the containing pane with a new editor containing a copy of the active edit session", ->
        editor.edit project.buildEditSessionForPath("sample.txt")
        editor.splitUp()
        expect(fakePane.splitUp).toHaveBeenCalled()
        [newEditor] = fakePane.splitUp.argsForCall[0]
        expect(newEditor.editSessions.length).toEqual 1
        expect(newEditor.activeEditSession.buffer).toBe editor.activeEditSession.buffer
        newEditor.remove()

    describe "when not inside a pane", ->
      it "does not split the editor, but doesn't throw an exception", ->
        editor.splitUp().remove()
        editor.splitDown().remove()
        editor.splitLeft().remove()
        editor.splitRight().remove()

  describe "editor-open event", ->
    it 'only triggers an editor-open event when it is first added to the DOM', ->
      openHandler = jasmine.createSpy('openHandler')
      editor.on 'editor-open', openHandler

      editor.simulateDomAttachment()
      expect(openHandler).toHaveBeenCalled()
      [event, eventEditor] = openHandler.argsForCall[0]
      expect(eventEditor).toBe editor

      openHandler.reset()
      editor.simulateDomAttachment()
      expect(openHandler).not.toHaveBeenCalled()

  describe "editor-path-change event", ->
    path = null
    beforeEach ->
      path = "/tmp/something.txt"
      fs.write(path, path)

    afterEach ->
      fs.remove(path) if fs.exists(path)

    it "emits event when buffer's path is changed", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor-path-change', eventHandler
      editor.getBuffer().saveAs(path)
      expect(eventHandler).toHaveBeenCalled()

    it "emits event when editor receives a new buffer", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor-path-change', eventHandler
      editor.edit(rootView.project.buildEditSessionForPath(path))
      expect(eventHandler).toHaveBeenCalled()

    it "stops listening to events on previously set buffers", ->
      eventHandler = jasmine.createSpy('eventHandler')
      oldBuffer = editor.getBuffer()
      editor.on 'editor-path-change', eventHandler

      editor.edit(rootView.project.buildEditSessionForPath(path))
      expect(eventHandler).toHaveBeenCalled()

      eventHandler.reset()
      oldBuffer.saveAs("/tmp/atom-bad.txt")
      expect(eventHandler).not.toHaveBeenCalled()

      eventHandler.reset()
      editor.getBuffer().saveAs("/tmp/atom-new.txt")
      expect(eventHandler).toHaveBeenCalled()

  describe "font size", ->
    it "sets the initial font size based on the value assigned to the root view", ->
      rootView.setFontSize(20)
      rootView.simulateDomAttachment()
      newEditor = editor.splitRight()
      expect(editor.css('font-size')).toBe '20px'
      expect(newEditor.css('font-size')).toBe '20px'

    describe "when the font size changes on the view", ->
      it "updates the font sizes of editors and recalculates dimensions critical to cursor positioning", ->
        rootView.attachToDom()
        rootView.setFontSize(10)
        lineHeightBefore = editor.lineHeight
        charWidthBefore = editor.charWidth
        editor.setCursorScreenPosition [5, 5]

        rootView.setFontSize(30)
        expect(editor.css('font-size')).toBe '30px'
        expect(editor.lineHeight).toBeGreaterThan lineHeightBefore
        expect(editor.charWidth).toBeGreaterThan charWidthBefore
        expect(editor.getCursorView().position()).toEqual { top: 5 * editor.lineHeight, left: 5 * editor.charWidth }

        # ensure we clean up font size subscription
        editor.trigger('core:close')
        rootView.setFontSize(22)
        expect(editor.css('font-size')).toBe '30px'

      it "updates the gutter width and font size", ->
        rootView.attachToDom()
        originalFontSize = rootView.getFontSize()
        originalGutterWidth = editor.gutter.width()

        rootView.setFontSize(originalFontSize * 4)
        expect(editor.gutter.css('font-size')).toBe "#{originalFontSize * 4}px"
        expect(editor.gutter.width()).toBe(originalGutterWidth * 4)

      it "updates lines if there are unrendered lines", ->
        editor.attachToDom(heightInLines: 5)
        originalLineCount = editor.renderedLines.find(".line").length
        expect(originalLineCount).toBeGreaterThan 0
        editor.setFontSize(10)
        expect(editor.renderedLines.find(".line").length).toBeGreaterThan originalLineCount

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

    describe "double-click", ->
      it "selects the word under the cursor", ->
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 1})
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 2})
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelectedText()).toBe "quicksort"

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

    describe "shift-click", ->
      it "selects from the cursor's current location to the clicked location", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true)
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

    describe "shift-double-click", ->
      it "expands the selection to include the double-clicked word", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 27]]

    describe "shift-triple-click", ->
      it "expands the selection to include the triple-clicked line", ->
        editor.setCursorScreenPosition([4, 7])
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
        editor.renderedLines.trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 3 })
        editor.renderedLines.trigger 'mouseup'
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 30]]

    describe "meta-click", ->
      it "places an additional cursor", ->
        editor.attachToDom()
        setEditorHeightInLines(editor, 5)
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 0])
        editor.scrollTop(editor.lineHeight * 6)

        spyOn(editor, "scrollTo").andCallThrough()

        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [6, 0], metaKey: true)
        expect(editor.scrollTo.callCount).toBe 1

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
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [5, 27])

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

    describe "double-click and drag", ->
      it "creates a selection from the word underneath an initial double click to mouse's new location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # double click
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 2})

        # moving changes selection
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 4})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 4})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

    describe "trip-click and drag", ->
      it "creates a selection from the line underneath an initial triple click to mouse's new location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # double click
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 2})
        $(document).trigger 'mouseup'
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 3})

        # moving changes selection
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.renderedLines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

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
          expect(region1.width()).toBeCloseTo(editor.renderedLines.width() - region1.position().left)

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
          expect(region1.width()).toBeCloseTo(editor.renderedLines.width() - region1.position().left)

          region2 = selectionView.regions[1]
          expect(region2.position().top).toBeCloseTo(3 * lineHeight)
          expect(region2.position().left).toBeCloseTo(0)
          expect(region2.height()).toBeCloseTo(3 * lineHeight)
          expect(region2.width()).toBeCloseTo(editor.renderedLines.width())

          # resizes with the editor
          expect(editor.width()).toBeLessThan(800)
          editor.width(800)
          expect(region2.width()).toBe(editor.renderedLines.width())

          region3 = selectionView.regions[2]
          expect(region3.position().top).toBeCloseTo(6 * lineHeight)
          expect(region3.position().left).toBeCloseTo(0)
          expect(region3.height()).toBeCloseTo lineHeight
          expect(region3.width()).toBeCloseTo(25 * charWidth)

      it "clears previously drawn regions before creating new ones", ->
        selection.setBufferRange(new Range({row: 2, column: 7}, {row: 4, column: 25}))
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.selection').length).toBe 3

        selectionView.updateAppearance()
        expect(selectionView.regions.length).toBe 3
        expect(selectionView.find('.selection').length).toBe 3

    describe "when a selection merges with another selection", ->
      it "removes the merged selection view", ->
        editSession = editor.activeEditSession
        editSession.setCursorScreenPosition([4, 10])
        editSession.selectToScreenPosition([5, 27])
        editSession.addCursorAtScreenPosition([3, 10])
        editSession.selectToScreenPosition([6, 27])

        expect(editor.getSelectionViews().length).toBe 1
        expect(editor.find('.selection').length).toBe 3

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

      it "removes the idle class while moving, then adds it back when it stops", ->
        cursorView = editor.getCursorView()
        advanceClock(200)

        expect(cursorView).toHaveClass 'idle'
        editor.setCursorScreenPosition([1, 2])
        expect(cursorView).not.toHaveClass 'idle'

        window.advanceClock(200)
        expect(cursorView).toHaveClass 'idle'

        editor.setCursorScreenPosition([1, 3])
        advanceClock(100)

        editor.setCursorScreenPosition([1, 4])
        advanceClock(100)
        expect(cursorView).not.toHaveClass 'idle'

        advanceClock(100)
        expect(cursorView).toHaveClass 'idle'

      describe "auto-scrolling", ->
        it "only auto-scrolls when the last cursor is moved", ->
          editor.setCursorBufferPosition([11,0])
          editor.addCursorAtBufferPosition([6,50])
          [cursor1, cursor2] = editor.getCursors()

          spyOn(editor, 'scrollTo')
          cursor1.setScreenPosition([10, 10])
          expect(editor.scrollTo).not.toHaveBeenCalled()

          cursor2.setScreenPosition([11, 11])
          expect(editor.scrollTo).toHaveBeenCalled()

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
                expect(editor.scrollView.scrollLeft()).toBe 0

                editor.setCursorScreenPosition([2, 25])
                expect(editor.scrollView.scrollLeft()).toBe charWidth

                editor.setCursorScreenPosition([2, 28])
                expect(editor.scrollView.scrollLeft()).toBe charWidth * 4

                # moving left
                editor.setCursorScreenPosition([2, 9])
                expect(editor.scrollView.scrollLeft()).toBe charWidth * 4

                editor.setCursorScreenPosition([2, 8])
                expect(editor.scrollView.scrollLeft()).toBe charWidth * 3

                editor.setCursorScreenPosition([2, 5])
                expect(editor.scrollView.scrollLeft()).toBe 0

            describe "when the editor is narrower than twice the horizontal scroll margin", ->
              it "sets the scrollView's scrollLeft based on a reduced horizontal scroll margin, to prevent a jerky tug-of-war between right and left scroll margins", ->
                editor.hScrollMargin = 6
                setEditorWidthInChars(editor, 7)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editor.scrollView.scrollLeft()).toBe(0)

                editor.setCursorScreenPosition([2, 4])
                window.advanceClock()
                expect(editor.scrollView.scrollLeft()).toBe(charWidth)

                editor.setCursorScreenPosition([2, 3])
                window.advanceClock()
                expect(editor.scrollView.scrollLeft()).toBe(0)

          describe "when soft-wrap is enabled", ->
            beforeEach ->
              editor.setSoftWrap(true)

            it "does not scroll the buffer horizontally", ->
              editor.width(charWidth * 30)

              # moving right
              editor.setCursorScreenPosition([2, 24])
              expect(editor.scrollView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 25])
              expect(editor.scrollView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 28])
              expect(editor.scrollView.scrollLeft()).toBe 0

              # moving left
              editor.setCursorScreenPosition([2, 9])
              expect(editor.scrollView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 8])
              expect(editor.scrollView.scrollLeft()).toBe 0

              editor.setCursorScreenPosition([2, 5])
              expect(editor.scrollView.scrollLeft()).toBe 0

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
        expect(line12.find('span:eq(1)')).toMatchSelector '.keyword'

      describe "when lines are updated in the buffer", ->
        it "syntax highlights the updated lines", ->
          expect(editor.renderedLines.find('.line:eq(0) > span:first > span:first')).toMatchSelector '.storage.modifier.js'
          buffer.insert([0, 0], "q")
          expect(editor.renderedLines.find('.line:eq(0) > span:first > span:first')).not.toMatchSelector '.storage.modifier.js'

          # verify that re-highlighting can occur below the changed line
          buffer.insert([5,0], "/* */")
          buffer.insert([1,0], "/*")
          expect(editor.renderedLines.find('.line:eq(2) > span:first > span:first')).toMatchSelector '.comment'

      describe "when soft-wrap is enabled", ->
        beforeEach ->
          setEditorHeightInLines(editor, 20)
          setEditorWidthInChars(editor, 50)
          editor.setSoftWrap(true)
          expect(editor.activeEditSession.softWrapColumn).toBe 50

        it "wraps lines that are too long to fit within the editor's width, adjusting cursor positioning accordingly", ->
          expect(editor.renderedLines.find('.line').length).toBe 16
          expect(editor.renderedLines.find('.line:eq(3)').text()).toBe "    var pivot = items.shift(), current, left = [], "
          expect(editor.renderedLines.find('.line:eq(4)').text()).toBe "right = [];"

          editor.setCursorBufferPosition([3, 51])
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
          $(window).trigger 'resize'
          expect(editor.renderedLines.find('.line').length).toBe 19
          expect(editor.renderedLines.find('.line:eq(4)').text()).toBe "left = [], right = [];"
          expect(editor.renderedLines.find('.line:eq(5)').text()).toBe "    while(items.length > 0) {"
          expect(editor.bufferPositionForScreenPosition(editor.getCursorScreenPosition())).toEqual [3, 60]

        it "does not wrap the lines of any newly assigned buffers", ->
          otherEditSession = rootView.project.buildEditSessionForPath()
          otherEditSession.buffer.setText([1..100].join(''))
          editor.edit(otherEditSession)
          expect(editor.renderedLines.find('.line').length).toBe(1)

        it "unwraps lines and cancels window resize listener when softwrap is disabled", ->
          editor.toggleSoftWrap()
          expect(editor.renderedLines.find('.line:eq(3)').text()).toBe '    var pivot = items.shift(), current, left = [], right = [];'

          spyOn(editor, 'setSoftWrapColumn')
          $(window).trigger 'resize'
          expect(editor.setSoftWrapColumn).not.toHaveBeenCalled()

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

        it "calls .setSoftWrapColumn() when the editor is attached because now its dimensions are available to calculate it", ->
          otherEditor = new Editor(editSession: rootView.project.buildEditSessionForPath('sample.js'))
          spyOn(otherEditor, 'setSoftWrapColumn')

          otherEditor.setSoftWrap(true)
          expect(otherEditor.setSoftWrapColumn).not.toHaveBeenCalled()

          otherEditor.simulateDomAttachment()
          expect(otherEditor.setSoftWrapColumn).toHaveBeenCalled()

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
            expect(editor.gutter.find('.line-number:last').text()).toBe '8'

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
            expect(editor.gutter.find('.line-number:first').text()).toBe '2'
            expect(editor.gutter.find('.line-number:last').text()).toBe '11'

            # here we don't scroll far enough to trigger additional rendering
            editor.scrollTop(editor.lineHeight * 5.5) # first visible row will be 5, last will be 10
            expect(editor.renderedLines.find('.line').length).toBe 10
            expect(editor.renderedLines.find('.line:first').text()).toBe buffer.lineForRow(1)
            expect(editor.renderedLines.find('.line:last').html()).toBe '&nbsp;' # line 10 is blank
            expect(editor.gutter.find('.line-number:first').text()).toBe '2'
            expect(editor.gutter.find('.line-number:last').text()).toBe '11'

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
            editor.scrollTop(editor.scrollView.prop('scrollHeight') - editor.scrollView.height())
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
        spyOn(editor, "scrollTo")

      describe "when the change the precedes the first rendered row", ->
        it "inserts and removes rendered lines to account for upstream change", ->
          editor.scrollToBottom()
          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[1,0], [3,0]], "1\n2\n3\n")
          expect(editor.renderedLines.find(".line").length).toBe 8
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(13)

      describe "when the change straddles the first rendered row", ->
        it "doesn't render rows that were not previously rendered", ->
          editor.scrollToBottom()

          expect(editor.renderedLines.find(".line").length).toBe 7
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(12)

          buffer.change([[2,0], [7,0]], "2\n3\n4\n5\n6\n7\n8\n9\n")
          expect(editor.renderedLines.find(".line").length).toBe 9
          expect(editor.renderedLines.find(".line:first").text()).toBe buffer.lineForRow(6)
          expect(editor.renderedLines.find(".line:last").text()).toBe buffer.lineForRow(14)

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
        maxLineLength = editor.maxScreenLineLength()
        setEditorWidthInChars(editor, maxLineLength)
        widthBefore = editor.renderedLines.width()
        expect(widthBefore).toBe editor.scrollView.width()
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editor.renderedLines.width()).toBeGreaterThan widthBefore

    describe "when lines are removed", ->
      beforeEach ->
        editor.attachToDom(heightInLines: 5)
        spyOn(editor, "scrollTo")

      it "sets the rendered screen line's width to either the max line length or the scollView's width (whichever is greater)", ->
        maxLineLength = editor.maxScreenLineLength()
        setEditorWidthInChars(editor, maxLineLength)
        buffer.change([[12,0], [12,0]], [1..maxLineLength*2].join(''))
        expect(editor.renderedLines.width()).toBeGreaterThan editor.scrollView.width()
        widthBefore = editor.renderedLines.width()
        buffer.delete([[12, 0], [12, Infinity]])
        expect(editor.renderedLines.width()).toBe editor.scrollView.width()

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

    describe "when autoscrolling at the end of the document", ->
      it "renders lines properly", ->
        editor.edit(rootView.project.buildEditSessionForPath('two-hundred.txt'))
        editor.attachToDom(heightInLines: 5.5)

        expect(editor.renderedLines.find('.line').length).toBe 8

        editor.moveCursorToBottom()

        expect(editor.renderedLines.find('.line').length).toBe 8

    describe "when line has a character that could push it to be too tall (regression)", ->
      it "does renders the line at a consistent height", ->
        rootView.attachToDom()
        buffer.insert([0, 0], "–")
        expect(editor.find('.line:eq(0)').outerHeight()).toBe editor.find('.line:eq(1)').outerHeight()

    describe ".spliceLineElements(startRow, rowCount, lineElements)", ->
      elements = null

      beforeEach ->
        editor.attachToDom()
        elements = $$ ->
          @div "A", class: 'line'
          @div "B", class: 'line'

      describe "when the start row is 0", ->
        describe "when the row count is 0", ->
          it "inserts the given elements before the first row", ->
            editor.spliceLineElements 0, 0, elements

            expect(editor.renderedLines.find('.line:eq(0)').text()).toBe 'A'
            expect(editor.renderedLines.find('.line:eq(1)').text()).toBe 'B'
            expect(editor.renderedLines.find('.line:eq(2)').text()).toBe 'var quicksort = function () {'

        describe "when the row count is > 0", ->
          it "replaces the initial rows with the given elements", ->
            editor.spliceLineElements 0, 2, elements

            expect(editor.renderedLines.find('.line:eq(0)').text()).toBe 'A'
            expect(editor.renderedLines.find('.line:eq(1)').text()).toBe 'B'
            expect(editor.renderedLines.find('.line:eq(2)').text()).toBe '    if (items.length <= 1) return items;'

      describe "when the start row is less than the last row", ->
        describe "when the row count is 0", ->
          it "inserts the elements at the specified location", ->
            editor.spliceLineElements 2, 0, elements

            expect(editor.renderedLines.find('.line:eq(2)').text()).toBe 'A'
            expect(editor.renderedLines.find('.line:eq(3)').text()).toBe 'B'
            expect(editor.renderedLines.find('.line:eq(4)').text()).toBe '    if (items.length <= 1) return items;'

        describe "when the row count is > 0", ->
          it "replaces the elements at the specified location", ->
            editor.spliceLineElements 2, 2, elements

            expect(editor.renderedLines.find('.line:eq(2)').text()).toBe 'A'
            expect(editor.renderedLines.find('.line:eq(3)').text()).toBe 'B'
            expect(editor.renderedLines.find('.line:eq(4)').text()).toBe '    while(items.length > 0) {'

      describe "when the start row is the last row", ->
        it "appends the elements to the end of the lines", ->
          editor.spliceLineElements 13, 0, elements

          expect(editor.renderedLines.find('.line:eq(12)').text()).toBe '};'
          expect(editor.renderedLines.find('.line:eq(13)').text()).toBe 'A'
          expect(editor.renderedLines.find('.line:eq(14)').text()).toBe 'B'
          expect(editor.renderedLines.find('.line:eq(15)')).not.toExist()

    describe "when editSession.showInvisibles is true", ->
      beforeEach ->
        project.setShowInvisibles(true)
        rootView.open()
        editor.attachToDom(5)

      it "displays spaces as •, tabs as ▸ and newlines as ¬", ->
        editor.setText " a line with tabs\tand spaces "
        expect(editor.find('.line').text()).toBe "•a line with tabs▸ and spaces•¬"

  describe "gutter rendering", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5.5)

    it "creates a line number element for each visible line, plus overdraw", ->
      expect(editor.gutter.find('.line-number').length).toBe 8
      expect(editor.find('.line-number:first').text()).toBe "1"
      expect(editor.gutter.find('.line-number:last').text()).toBe "8"

      # here we don't scroll far enough to trigger additional rendering
      editor.scrollTop(editor.lineHeight * 1.5)
      expect(editor.renderedLines.find('.line').length).toBe 8
      expect(editor.gutter.find('.line-number:first').text()).toBe "1"
      expect(editor.gutter.find('.line-number:last').text()).toBe "8"

      editor.scrollTop(editor.lineHeight * 3.5)
      expect(editor.renderedLines.find('.line').length).toBe 10
      expect(editor.gutter.find('.line-number:first').text()).toBe "2"
      expect(editor.gutter.find('.line-number:last').text()).toBe "11"

    describe "width", ->
      it "sets the width based on largest line number", ->
        expect(editor.gutter.lineNumbers.outerWidth()).toBe(editor.charWidth * 2 + editor.gutter.calculateLineNumberPadding())

      it "updates the width and the left position of the scroll view when total number of lines gains a digit", ->
        editor.setText("")

        expect(editor.gutter.lineNumbers.outerWidth()).toBe(editor.charWidth * 1 + editor.gutter.calculateLineNumberPadding())
        expect(parseInt(editor.scrollView.css('left'))).toBe editor.gutter.outerWidth()

        for i in [1..9] # Ends on an empty line 10
          editor.insertText "#{i}\n"

        expect(editor.gutter.lineNumbers.outerWidth()).toBe(editor.charWidth * 2 + editor.gutter.calculateLineNumberPadding())
        expect(parseInt(editor.scrollView.css('left'))).toBe editor.gutter.outerWidth()

    describe "when lines are inserted", ->
      it "re-renders the correct line number range in the gutter", ->
        spyOn(editor, 'scrollTo')
        editor.scrollTop(3 * editor.lineHeight)
        expect(editor.gutter.find('.line-number:first').text()).toBe '2'
        expect(editor.gutter.find('.line-number:last').text()).toBe '11'

        buffer.insert([6, 0], '\n')

        expect(editor.gutter.find('.line-number:first').text()).toBe '2'
        expect(editor.gutter.find('.line-number:last').text()).toBe '11'

    describe "when the insertion of lines causes the editor to scroll", ->
      it "renders line numbers correctly", ->
        oneHundredLines = [0..100].join("\n")
        editor.insertText(oneHundredLines)
        expect(editor.gutter.lineNumbers.find('.line-number').length).toBe 6 + editor.lineOverdraw * 2

    describe "when wrapping is on", ->
      it "renders a • instead of line number for wrapped portions of lines", ->
        editor.setSoftWrapColumn(50)
        expect(editor.gutter.find('.line-number').length).toEqual(8)
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '•'
        expect(editor.gutter.find('.line-number:eq(5)').text()).toBe '5'

    describe "when there are folds", ->
      it "skips line numbers covered by the fold and updates them when the fold changes", ->
        editor.createFold(3, 5)
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '7'

        buffer.insert([4,0], "\n\n")
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '9'

        buffer.delete([[3,0], [6,0]])
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '6'

      it "redraws gutter numbers when lines are unfolded", ->
        setEditorHeightInLines(editor, 20)
        fold = editor.createFold(2, 12)
        expect(editor.gutter.find('.line-number').length).toBe 3

        fold.destroy()
        expect(editor.gutter.find('.line-number').length).toBe 13

    describe "when the scrollView is scrolled to the right", ->
      it "adds a drop shadow to the gutter", ->
        editor.attachToDom()
        editor.width(100)

        expect(editor.gutter).not.toHaveClass('drop-shadow')

        editor.scrollView.scrollLeft(10)
        editor.scrollView.trigger('scroll')

        expect(editor.gutter).toHaveClass('drop-shadow')

        editor.scrollView.scrollLeft(0)
        editor.scrollView.trigger('scroll')

        expect(editor.gutter).not.toHaveClass('drop-shadow')

    describe "when the editor is scrolled vertically", ->
      it "adjusts the padding-top to account for non-rendered line numbers", ->
        editor.scrollTop(editor.lineHeight * 3.5)
        expect(editor.gutter.lineNumbers.css('padding-top')).toBe "#{editor.lineHeight * 1}px"
        expect(editor.gutter.lineNumbers.css('padding-bottom')).toBe "#{editor.lineHeight * 2}px"
        expect(editor.renderedLines.find('.line').length).toBe 10
        expect(editor.gutter.find('.line-number:first').text()).toBe "2"
        expect(editor.gutter.find('.line-number:last').text()).toBe "11"

    describe "when the editor is mini", ->
      it "hides the gutter and does not change the scroll view's left position", ->
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.gutter).toBeHidden()
        expect(miniEditor.scrollView.css('left')).toBe '0px'

      it "doesn't highlight the only line", ->
        miniEditor = new Editor(mini: true)
        miniEditor.attachToDom()
        expect(miniEditor.getCursorBufferPosition().row).toBe 0
        expect(miniEditor.find('.line.cursor-line').length).toBe 0

  describe "gutter line highlighting", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5.5)

    describe "when there is no wrapping", ->
      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line-number.cursor-line-number').length).toBe 1
        expect(editor.find('.line-number.cursor-line-number').text()).toBe "1"

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line-number.cursor-line-number').length).toBe 1
        expect(editor.find('.line-number.cursor-line-number').text()).toBe "2"

    describe "when there is wrapping", ->
      beforeEach ->
        editor.attachToDom(30)
        editor.setSoftWrap(true)
        setEditorWidthInChars(editor, 20)

      it "highlights the line where the initial cursor position is", ->
        expect(editor.getCursorBufferPosition().row).toBe 0
        expect(editor.find('.line-number.cursor-line-number.cursor-line-number-background').length).toBe 1
        expect(editor.find('.line-number.cursor-line-number.cursor-line-number-background').text()).toBe "1"

      it "updates the highlighted line when the cursor position changes", ->
        editor.setCursorBufferPosition([1,0])
        expect(editor.getCursorBufferPosition().row).toBe 1
        expect(editor.find('.line-number.cursor-line-number.cursor-line-number-background').length).toBe 1
        expect(editor.find('.line-number.cursor-line-number.cursor-line-number-background').text()).toBe "2"

    describe "when the selection spans multiple lines", ->
      beforeEach ->
        editor.attachToDom(30)

      it "doesn't highlight the backround", ->
        editor.getSelection().setBufferRange(new Range([0,0],[2,0]))
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editor.find('.line-number.cursor-line-number').length).toBe 1
        expect(editor.find('.line-number.cursor-line-number.cursor-line-number-background').length).toBe 0
        expect(editor.find('.line-number.cursor-line-number').text()).toBe "3"

    it "when a newline is deleted with backspace, the line number of the new cursor position is highlighted", ->
      editor.setCursorScreenPosition([1,0])
      editor.backspace()
      expect(editor.find('.line-number.cursor-line-number').length).toBe 1
      expect(editor.find('.line-number.cursor-line-number').text()).toBe "1"
      expect(editor.find('.line-number.cursor-line-number-background').length).toBe 1
      expect(editor.find('.line-number.cursor-line-number-background').text()).toBe "1"

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
        editor.setSoftWrap(true)
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

    describe "when there is a selection", ->
      it "highlights if the selection is contained to one line", ->
        editor.getSelection().setBufferRange(new Range([0,0],[0,1]))
        expect(editor.getSelection().isSingleScreenLine()).toBe true
        expect(editor.find('.line.cursor-line').length).toBe 1
        expect(editor.find('.line.cursor-line').text()).toBe buffer.lineForRow(0)

      it "doesn't highlight if the selection spans multiple lines", ->
        editor.getSelection().setBufferRange(new Range([0,0],[2,0]))
        expect(editor.getSelection().isSingleScreenLine()).toBe false
        expect(editor.find('.line.cursor-line').length).toBe 0

  describe "folding", ->
    beforeEach ->
      editSession = rootView.project.buildEditSessionForPath('two-hundred.txt')
      buffer = editSession.buffer
      editor.edit(editSession)
      editor.attachToDom()

    describe "when a fold-selection event is triggered", ->
      it "folds the lines covered by the selection into a single line with a fold class", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'editor:fold-selection'

        expect(editor.renderedLines.find('.line:eq(4)')).toHaveClass('fold')
        expect(editor.renderedLines.find('.line:eq(5)').text()).toBe '8'

        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.getCursorScreenPosition()).toEqual [5, 0]

    describe "when a fold placeholder line is clicked", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.setCursorBufferPosition([3,0])
        editor.trigger 'editor:fold-current-row'

        editor.find('.fold.line').mousedown()

        expect(editor.find('.fold')).not.toExist()
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

        editor.setSelectedBufferRange([[1, 0], [2, 0]], preserveFolds: true, reverse: true)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

        editor.setSelectedBufferRange([[1, 0], [1, 1]], preserveFolds: true)
        expect(editor.lineElementForScreenRow(2)).not.toMatchSelector('.fold.selected')

        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

        editor.setCursorScreenPosition([3,0])
        expect(editor.lineElementForScreenRow(2)).not.toMatchSelector('.fold.selected')

        editor.setCursorScreenPosition([2,0])
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')
        expect(editor.find('.cursor').css('display')).toBe 'none'

        editor.setCursorScreenPosition([3,0])
        expect(editor.find('.cursor').css('display')).toBe 'block'

    describe "when a selected fold is scrolled into view (and the fold line was not previously rendered)", ->
      it "renders the fold's line element with the 'selected' class", ->
        setEditorHeightInLines(editor, 5)
        editor.renderLines() # re-render lines so certain lines are not rendered

        editor.createFold(2, 4)
        editor.setSelectedBufferRange([[1, 0], [5, 0]], preserveFolds: true)
        expect(editor.renderedLines.find('.fold.selected')).toExist()

        editor.scrollToBottom()
        expect(editor.renderedLines.find('.fold.selected')).not.toExist()

        editor.scrollTop(0)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

  describe ".getOpenBufferPaths()", ->
    it "returns the paths of all non-anonymous buffers with edit sessions on this editor", ->
      editor.edit(project.buildEditSessionForPath('sample.txt'))
      editor.edit(project.buildEditSessionForPath('two-hundred.txt'))
      editor.edit(project.buildEditSessionForPath())
      paths = editor.getOpenBufferPaths().map (path) -> project.relativize(path)
      expect(paths).toEqual = ['sample.js', 'sample.txt', 'two-hundred.txt']

  describe "paging up and down", ->
    beforeEach ->
      editor.attachToDom()

    it "moves to the last line when page down is repeated from the first line", ->
      rows = editor.getLineCount() - 1
      expect(rows).toBeGreaterThan(0)
      row = editor.getCursor(0).getScreenPosition().row
      expect(row).toBe(0)
      while row < rows
        editor.pageDown()
        newRow = editor.getCursor(0).getScreenPosition().row
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
