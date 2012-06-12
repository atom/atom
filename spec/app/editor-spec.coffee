RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'
Project = require 'project'
$ = require 'jquery'
{$$} = require 'space-pen'
_ = require 'underscore'
fs = require 'fs'

describe "Editor", ->
  [rootView, buffer, editor, cachedLineHeight] = []

  getLineHeight = ->
    return cachedLineHeight if cachedLineHeight?
    editorForMeasurement = new Editor()
    editorForMeasurement.attachToDom()
    cachedLineHeight = editorForMeasurement.lineHeight
    editorForMeasurement.remove()
    cachedLineHeight

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    project = rootView.project
    editor = rootView.activeEditor()
    buffer = editor.buffer

    editor.attachToDom = ({ heightInLines } = {}) ->
      heightInLines ?= this.buffer.getLineCount()
      this.height(getLineHeight() * heightInLines)
      $('#jasmine-content').append(this)

    editor.lineOverdraw = 2
    editor.setAutoIndent(false)
    editor.enableKeymap()
    editor.isFocused = true

  afterEach ->
    editor.remove()

  describe "construction", ->
    it "assigns an empty buffer and correctly handles text input (regression coverage)", ->
      editor = new Editor
      editor.attachToDom()
      expect(editor.buffer.getPath()).toBeUndefined()
      expect(editor.renderedLines.find('.line').length).toBe 1
      editor.insertText('x')
      expect(editor.renderedLines.find('.line').length).toBe 1

  describe ".copy()", ->
    it "builds a new editor with the same edit sessions, cursor position, and scroll position as the receiver", ->
      rootView.attachToDom()
      rootView.height(8 * editor.lineHeight)
      rootView.width(50 * editor.charWidth)

      editor.setCursorScreenPosition([5, 20])
      advanceClock()
      editor.scrollTop(1.5 * editor.lineHeight)
      editor.scrollView.scrollLeft(44)

      # prove this test covers serialization and deserialization
      spyOn(editor, 'serialize').andCallThrough()
      spyOn(Editor, 'deserialize').andCallThrough()

      newEditor = editor.copy()
      expect(editor.serialize).toHaveBeenCalled()
      expect(Editor.deserialize).toHaveBeenCalled()

      expect(newEditor.buffer).toBe editor.buffer
      expect(newEditor.getCursorScreenPosition()).toEqual editor.getCursorScreenPosition()
      expect(newEditor.editSessions[0]).toEqual(editor.editSessions[0])
      expect(newEditor.editSessions[0]).not.toBe(editor.editSessions[0])

      newEditor.height(editor.height())
      newEditor.width(editor.width())
      rootView.remove()
      newEditor.attachToDom()
      expect(newEditor.scrollTop()).toBe editor.scrollTop()
      expect(newEditor.scrollView.scrollLeft()).toBe 44
      newEditor.remove()

  describe ".remove()", ->
    it "removes subscriptions from all edit session buffers", ->
      otherBuffer = new Buffer(require.resolve('fixtures/sample.txt'))
      expect(buffer.subscriptionCount()).toBeGreaterThan 1

      editor.setBuffer(otherBuffer)
      expect(otherBuffer.subscriptionCount()).toBeGreaterThan 1

      editor.remove()
      expect(buffer.subscriptionCount()).toBe 1
      expect(otherBuffer.subscriptionCount()).toBe 1

  describe ".setBuffer(buffer)", ->
    otherBuffer = null

    beforeEach ->
      otherBuffer = new Buffer

    describe "when the buffer wasn't previously assigned to this editor", ->
      it "creates a new EditSession for it", ->
        editor.setBuffer(otherBuffer)
        expect(editor.activeEditSession.buffer).toBe otherBuffer

    describe "when the buffer was previously assigned to this editor", ->
      it "restores the previous edit session associated with the buffer", ->
        previousEditSession = editor.activeEditSession

        editor.setBuffer(otherBuffer)
        expect(editor.activeEditSession).not.toBe previousEditSession

        editor.setBuffer(buffer)
        expect(editor.activeEditSession).toBe previousEditSession

    it "unsubscribes from the previously assigned buffer", ->
      editor.setBuffer(otherBuffer)

      previousSubscriptionCount = buffer.subscriptionCount()

      editor.setBuffer(buffer)
      editor.setBuffer(otherBuffer)

      expect(buffer.subscriptionCount()).toBe previousSubscriptionCount

    it "handles buffer manipulation correctly after switching to a new buffer", ->
      editor.attachToDom()
      editor.insertText("abc\n")
      expect(editor.lineElementForScreenRow(0).text()).toBe 'abc'

      editor.setBuffer(otherBuffer)
      expect(editor.lineElementForScreenRow(0).html()).toBe '&nbsp;'

      editor.insertText("def\n")
      expect(editor.lineElementForScreenRow(0).text()).toBe 'def'

  describe ".save()", ->
    describe "when the current buffer has a path", ->
      tempFilePath = null

      beforeEach ->
        tempFilePath = '/tmp/atom-temp.txt'
        editor.setBuffer new Buffer(tempFilePath)
        expect(editor.buffer.getPath()).toBe tempFilePath

      afterEach ->
        expect(fs.remove(tempFilePath))

      it "saves the current buffer to disk", ->
        editor.buffer.setText 'Edited!'
        expect(fs.exists(tempFilePath)).toBeFalsy()

        editor.save()

        expect(fs.exists(tempFilePath)).toBeTruthy()
        expect(fs.read(tempFilePath)).toBe 'Edited!'

    describe "when the current buffer has no path", ->
      selectedFilePath = null
      beforeEach ->
        editor.setBuffer new Buffer()
        expect(editor.buffer.getPath()).toBeUndefined()
        editor.buffer.setText 'Save me to a new path'
        spyOn($native, 'saveDialog').andCallFake -> selectedFilePath

      it "presents a 'save as' dialog", ->
        editor.save()
        expect($native.saveDialog).toHaveBeenCalled()

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

  describe "switching edit sessions", ->
    [buffer0, buffer1, buffer2] = []
    [session0, session1, session2] = []

    beforeEach ->
      buffer0 = buffer
      session0 = editor.activeEditSession

      buffer1 = new Buffer(require.resolve('fixtures/sample.txt'))
      editor.setBuffer(buffer1)
      session1 = editor.activeEditSession

      buffer2 = new Buffer(require.resolve('fixtures/two-hundred.txt'))
      editor.setBuffer(buffer2)
      session2 = editor.activeEditSession

    describe ".setActiveEditSessionIndex(index)", ->
      it "restores the buffer, cursors, selections, and scroll position of the edit session associated with the index", ->
        editor.attachToDom(heightInLines: 10)
        editor.setSelectionBufferRange([[40, 0], [43, 1]])
        expect(editor.getSelection().getScreenRange()).toEqual [[40, 0], [43, 1]]
        previousScrollHeight = editor.verticalScrollbar.prop('scrollHeight')
        editor.scrollTop(750)
        expect(editor.scrollTop()).toBe 750

        editor.setActiveEditSessionIndex(0)
        expect(editor.buffer).toBe buffer0

        editor.setActiveEditSessionIndex(2)
        expect(editor.buffer).toBe buffer2
        expect(editor.getCursorScreenPosition()).toEqual [43, 1]
        expect(editor.verticalScrollbar.prop('scrollHeight')).toBe previousScrollHeight
        expect(editor.scrollTop()).toBe 750
        expect(editor.getSelection().getScreenRange()).toEqual [[40, 0], [43, 1]]
        expect(editor.getSelectionView().find('.selection')).toExist()

        editor.setActiveEditSessionIndex(0)
        editor.activeEditSession.selectToEndOfLine()
        expect(editor.getSelectionView().find('.selection')).toExist()

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
        expect(editor.gutter.scrollTop()).toBe 100

        editor.scrollTop(120)
        expect(editor.verticalScrollbar.scrollTop()).toBe 120
        expect(editor.scrollView.scrollTop()).toBe 0
        expect(editor.renderedLines.css('top')).toBe "-120px"
        expect(editor.gutter.scrollTop()).toBe 120

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
          expect(editor.gutter.scrollTop()).toBe 100

    describe "when called with no argument", ->
      it "returns the last assigned value or 0 if none has been assigned", ->
        expect(editor.scrollTop()).toBe 0
        editor.scrollTop(50)
        expect(editor.scrollTop()).toBe 50

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

  describe "text rendering", ->
    describe "when all lines in the buffer are visible on screen", ->
      beforeEach ->
        editor.attachToDom()
        expect(editor.height()).toBe buffer.getLineCount() * editor.lineHeight

      it "creates a line element for each line in the buffer with the html-escaped text of the line", ->
        expect(editor.renderedLines.find('.line').length).toEqual(buffer.getLineCount())
        expect(buffer.lineForRow(2)).toContain('<')
        expect(editor.renderedLines.find('.line:eq(2)').html()).toContain '&lt;'

        # renders empty lines with a non breaking space
        expect(buffer.lineForRow(10)).toBe ''
        expect(editor.renderedLines.find('.line:eq(10)').html()).toBe '&nbsp;'

      it "syntax highlights code based on the file type", ->
        line1 = editor.renderedLines.find('.line:first')
        expect(line1.find('span:eq(0)')).toMatchSelector '.keyword.definition'
        expect(line1.find('span:eq(0)').text()).toBe 'var'
        expect(line1.find('span:eq(1)')).toMatchSelector '.text'
        expect(line1.find('span:eq(1)').text()).toBe ' '
        expect(line1.find('span:eq(2)')).toMatchSelector '.identifier'
        expect(line1.find('span:eq(2)').text()).toBe 'quicksort'
        expect(line1.find('span:eq(4)')).toMatchSelector '.operator'
        expect(line1.find('span:eq(4)').text()).toBe '='

        line12 = editor.renderedLines.find('.line:eq(11)')
        expect(line12.find('span:eq(1)')).toMatchSelector '.keyword'

      describe "when lines are updated in the buffer", ->
        it "syntax highlights the updated lines", ->
          expect(editor.renderedLines.find('.line:eq(0) span:eq(0)')).toMatchSelector '.keyword.definition'
          buffer.insert([0, 4], "g")
          expect(editor.renderedLines.find('.line:eq(0) span:eq(0)')).toMatchSelector '.keyword.definition'

          # verify that re-highlighting can occur below the changed line
          buffer.insert([5,0], "/* */")
          buffer.insert([1,0], "/*")
          expect(editor.renderedLines.find('.line:eq(2) span:eq(0)')).toMatchSelector '.comment'

      describe "when soft-wrap is enabled", ->
        beforeEach ->
          setEditorHeightInLines(editor, 20)
          setEditorWidthInChars(editor, 50)
          editor.setSoftWrap(true)
          expect(editor.renderer.softWrapColumn).toBe 50

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
          expect(region1.offset().top).toBe(editor.renderedLines.find('.line:eq(7)').offset().top)
          expect(region2.offset().top).toBe(editor.renderedLines.find('.line:eq(8)').offset().top)

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

        it "wraps the lines of any newly assigned buffers", ->
          otherBuffer = new Buffer
          otherBuffer.setText([1..100].join(''))
          editor.setBuffer(otherBuffer)
          expect(editor.renderedLines.find('.line').length).toBeGreaterThan(1)

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
          otherEditor = new Editor()
          spyOn(otherEditor, 'setSoftWrapColumn')

          otherEditor.setSoftWrap(true)
          expect(otherEditor.setSoftWrapColumn).not.toHaveBeenCalled()

          otherEditor.simulateDomAttachment()
          expect(otherEditor.setSoftWrapColumn).toHaveBeenCalled()
          otherEditor.remove()

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
        expect(editor.renderedLines.find('.line:eq(2)').text()).toBe editor.buffer.lineForRow(2)
        expect(editor.renderedLines.find('.line:eq(7)').text()).toBe editor.buffer.lineForRow(7)

      it "renders correctly when scrolling after text is removed from buffer", ->
        editor.buffer.delete([[0,0],[1,0]])
        expect(editor.renderedLines.find('.line:eq(0)').text()).toBe editor.buffer.lineForRow(0)
        expect(editor.renderedLines.find('.line:eq(5)').text()).toBe editor.buffer.lineForRow(5)

        editor.scrollTop(3 * editor.lineHeight)
        expect(editor.renderedLines.find('.line:first').text()).toBe editor.buffer.lineForRow(1)
        expect(editor.renderedLines.find('.line:last').text()).toBe editor.buffer.lineForRow(10)

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

      it "increases the width of the rendered lines element if the max line length changes", ->
        widthBefore = editor.renderedLines.width()
        buffer.change([[12,0], [12,0]], [1..50].join(''))
        expect(editor.renderedLines.width()).toBeGreaterThan widthBefore

    describe "when lines are removed", ->
      beforeEach ->
        editor.attachToDom(heightInLines: 5)
        spyOn(editor, "scrollTo")

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

      it "decreases the width of the rendered screen lines if the max line length changes", ->
        widthBefore = editor.renderedLines.width()
        buffer.delete([[6, 0], [6, Infinity]])
        expect(editor.renderedLines.width()).toBeLessThan widthBefore

    describe "when folding leaves less then a screen worth of text (regression)", ->
      it "renders lines properly", ->
        editor.lineOverdraw = 1
        editor.attachToDom(heightInLines: 5)
        editor.renderer.toggleFoldAtBufferRow(4)
        editor.renderer.toggleFoldAtBufferRow(0)

        expect(editor.renderedLines.find('.line').length).toBe 1
        expect(editor.renderedLines.find('.line').text()).toBe buffer.lineForRow(0)

    describe "when autoscrolling at the end of the document", ->
      it "renders lines properly", ->
        editor.setBuffer(new Buffer(require.resolve 'fixtures/two-hundred.txt'))
        editor.attachToDom(heightInLines: 5.5)
        expect(editor.renderedLines.find('.line').length).toBe 8

        editor.moveCursorToBottom()

        expect(editor.renderedLines.find('.line').length).toBe 8

  describe "gutter rendering", ->
    beforeEach ->
      editor.attachToDom(heightInLines: 5.5)

    it "creates a line number element for each visible line, plus overdraw", ->
      expect(editor.gutter.find('.line-number').length).toBe 8
      expect(editor.gutter.find('.line-number:first').text()).toBe "1"
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
      it "sets the width based on last line number", ->
        expect(editor.gutter.lineNumbers.outerWidth()).toBe editor.charWidth * 2

      it "updates the width when total number of lines gains a digit", ->
        oneHundredLines = [0..100].join("\n")
        editor.insertText(oneHundredLines)
        expect(editor.gutter.lineNumbers.outerWidth()).toBe editor.charWidth * 3

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
        editor.trigger('close')
        rootView.setFontSize(22)
        expect(editor.css('font-size')).toBe '30px'

      it "updates lines if there are unrendered lines", ->
        editor.attachToDom(heightInLines: 5)
        originalLineCount = editor.renderedLines.find(".line").length
        expect(originalLineCount).toBeGreaterThan 0
        editor.setFontSize(10)
        expect(editor.renderedLines.find(".line").length).toBeGreaterThan originalLineCount

  describe "cursor movement", ->
    describe ".setCursorScreenPosition({row, column})", ->
      beforeEach ->
        editor.attachToDom()
        editor.setCursorScreenPosition(row: 2, column: 2)

      it "moves the cursor to the character at the given row and column", ->
        expect(editor.getCursorView().position()).toEqual(top: 2 * editor.lineHeight, left: 2 * editor.charWidth)

    describe "when a mousedown event occurs in the editor", ->
      beforeEach ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

      describe "when soft-wrap and is enabled and code is folded", ->
        beforeEach ->
          setEditorWidthInChars(editor, 50)
          editor.setSoftWrap(true)
          editor.createFold(2, 3)

        describe "when it is a single click", ->
          it "re-positions the cursor from the clicked screen position to the corresponding buffer position", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [9, 0])
            expect(editor.getCursorBufferPosition()).toEqual(row: 8, column: 11)

        describe "when it is a double click", ->
          it "selects the word under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [9, 0], originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [9, 0], originalEvent: {detail: 2})
            expect(editor.getSelectedText()).toBe "sort"

        describe "when it is clicked more then twice (triple, quadruple, etc...)", ->
          it "selects the line under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

            # Triple click
            point = [9, 3]
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 2})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 3})
            editor.renderedLines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "    return sort(left).concat(pivot).concat(sort(right));"

            # Quad click
            point = [12, 3]
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 2})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 3})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: point, originalEvent: {detail: 4})
            editor.renderedLines.trigger 'mouseup'

            expect(editor.getSelectedText()).toBe "  return sort(Array.apply(this, arguments));"

      describe "when soft-wrap is disabled", ->
        describe "when it is a single click", ->
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

        describe "when it is a double click", ->
          it "selects the word under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 2})
            editor.renderedLines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "quicksort"

        describe "when it is clicked more then twice (triple, quadruple, etc...)", ->
          it "selects the line under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

            # Triple click
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 2})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 3})
            editor.renderedLines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "  var sort = function(items) {"

            # Quad click
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 1})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 2})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 3})
            editor.renderedLines.trigger 'mouseup'
            editor.renderedLines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 4})
            editor.renderedLines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "    if (items.length <= 1) return items;"

    describe "scrolling", ->
      describe "vertical scrolling", ->
        beforeEach ->
          editor.attachToDom()
          editor.focus()
          editor.vScrollMargin = 3

        it "scrolls the buffer with the specified scroll margin when cursor approaches the end of the screen", ->
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

        it "reduces scroll margins when there isn't enough height to maintain them and scroll smoothly", ->
          setEditorHeightInLines(editor, 5)

          _.times 3, -> editor.moveCursorDown()

          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorUp()
          expect(editor.renderedLines.css('top')).toBe "0px"

      describe "horizontal scrolling", ->
        charWidth = null
        beforeEach ->
          editor.attachToDom()
          {charWidth} = editor
          editor.hScrollMargin = 5

        it "scrolls horizontally to keep the cursor on screen", ->
          setEditorWidthInChars(editor, 30)

          # moving right
          editor.setCursorScreenPosition([2, 24])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe 0

          editor.setCursorScreenPosition([2, 25])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe charWidth

          editor.setCursorScreenPosition([2, 28])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe charWidth * 4

          # moving left
          editor.setCursorScreenPosition([2, 9])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe charWidth * 4

          editor.setCursorScreenPosition([2, 8])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe charWidth * 3

          editor.setCursorScreenPosition([2, 5])
          window.advanceClock()
          expect(editor.scrollView.scrollLeft()).toBe 0

        it "reduces scroll margins when there isn't enough width to maintain them and scroll smoothly", ->
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

        describe "when soft-wrap is on", ->
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

      describe "when there are multiple cursor", ->
        beforeEach ->
          editor.attachToDom()
          editor.focus()
          editor.vScrollMargin = 2

        it "only attempts to scroll when a cursor is visible", ->
          setEditorWidthInChars(editor, 20)
          setEditorHeightInLines(editor, 10)
          editor.setCursorBufferPosition([11,0])
          editor.addCursorAtBufferPosition([6,50])
          editor.addCursorAtBufferPosition([0,0])
          window.advanceClock()

          scrollHandler = spyOn(editor, 'scrollVertically')

          editor.moveCursorRight()
          window.advanceClock()
          position = editor.pixelPositionForScreenPosition([0,1])
          expect(scrollHandler).toHaveBeenCalledWith(position)

        it "only attempts to scroll once when multiple cursors are visible", ->
          setEditorWidthInChars(editor, 20)
          setEditorHeightInLines(editor, 10)
          editor.setCursorBufferPosition([11,0])
          editor.addCursorAtBufferPosition([0,0])
          editor.addCursorAtBufferPosition([6,0])
          window.advanceClock()

          scrollHandler = spyOn(editor, 'scrollVertically')

          editor.moveCursorRight()
          window.advanceClock()

          position = editor.pixelPositionForScreenPosition([6,1])
          expect(scrollHandler).toHaveBeenCalledWith(position)

    describe "when editing a line that spans multiple screen lines", ->
      beforeEach ->
        editor.setSoftWrap(true, 50)
        editor.setAutoIndent(true)

      describe "when newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(5)).toEqual("      ")

      describe "when text that closes a scope is entered", ->
        it "outdents the text", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(5)).toEqual("      ")
          editor.insertText("}")
          expect(editor.buffer.lineForRow(5)).toEqual("    }")
          expect(editor.getCursorBufferPosition().column).toBe 5

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.getSelection()

    describe "when the mouse is dragged across the text", ->
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

    describe "shift-click", ->
      beforeEach ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)
        editor.setCursorScreenPosition([4, 7])

      it "selects from the cursor's current location to the clicked location", ->
        editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true)
        expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 24]]

      describe "when it is a double-click", ->
        it "expands the selection to include the double-clicked word", ->
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
          expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 27]]

      describe "when it is a triple-click", ->
        it "expands the selection to include the triple-clicked line", ->
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 1 })
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 2 })
          editor.renderedLines.trigger mousedownEvent(editor: editor, point: [5, 24], shiftKey: true, originalEvent: { detail: 3 })
          expect(editor.getSelection().getScreenRange()).toEqual [[4, 7], [5, 30]]

  describe "multiple cursors", ->
    it "places multiple cursors with meta-click", ->
      editor.attachToDom()
      setEditorHeightInLines(editor, 5)
      editor.renderedLines.trigger mousedownEvent(editor: editor, point: [3, 0])
      editor.scrollTop(editor.lineHeight * 6)

      spyOn(editor, "scrollTo").andCallThrough()

      editor.renderedLines.trigger mousedownEvent(editor: editor, point: [6, 0], metaKey: true)
      expect(editor.scrollTo.callCount).toBe 1

      [cursor1, cursor2] = editor.find('.cursor').map -> $(this).view()
      expect(cursor1.position()).toEqual(top: 3 * editor.lineHeight, left: 0)
      expect(cursor1.getBufferPosition()).toEqual [3, 0]
      expect(cursor2.position()).toEqual(top: 6 * editor.lineHeight, left: 0)
      expect(cursor2.getBufferPosition()).toEqual [6, 0]

    describe "selections", ->
      describe "upon clicking and dragging with the meta-key held down", ->
        it "adds an additional selection upon clicking and dragging with the meta-key held down", ->
          editor.attachToDom()
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

  describe "buffer manipulation", ->
    beforeEach ->
      editor.attachToDom()

    describe "when text input events are triggered on the hidden input element", ->
      describe "when there is no selection", ->
        it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
          editor.setCursorScreenPosition(row: 1, column: 6)

          expect(buffer.lineForRow(1).charAt(6)).not.toBe 'q'

          editor.hiddenInput.textInput 'q'

          expect(buffer.lineForRow(1).charAt(6)).toBe 'q'
          expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 7)
          expect(editor.renderedLines.find('.line:eq(1)')).toHaveText buffer.lineForRow(1)

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

    it "unsubscribes from the buffer when it is removed from the dom", ->
      buffer = new Buffer
      previousSubscriptionCount = buffer.subscriptionCount()

      editor.attachToDom()
      editor.setBuffer(buffer)

      expect(buffer.subscriptionCount()).toBeGreaterThan previousSubscriptionCount
      expect($('.editor')).toExist()
      editor.remove()
      expect(buffer.subscriptionCount()).toBe previousSubscriptionCount
      expect($('.editor')).not.toExist()

  describe "when the editor recieves focused", ->
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

  describe "structural folding", ->
    describe "when a toggle-fold event is triggered", ->
      it "creates/destroys a structual fold based on cursor position", ->
        editor.setCursorBufferPosition([1,0])

        editor.trigger "toggle-fold"
        expect(editor.screenLineForRow(1).fold).toBeDefined()

        editor.trigger "toggle-fold"
        expect(editor.screenLineForRow(1).fold).toBeUndefined()

      it "creates/destroys the largest fold containing the cursor position", ->
        editor.trigger "fold-all"
        editor.setCursorBufferPosition([5,1])

        editor.trigger "toggle-fold"
        expect(editor.screenLineForRow(0).fold).toBeUndefined()
        expect(editor.screenLineForRow(1).fold).toBeDefined()

        editor.trigger "toggle-fold"
        expect(editor.screenLineForRow(0).fold).toBeUndefined()
        expect(editor.screenLineForRow(1).fold).toBeUndefined()
        expect(editor.screenLineForRow(4).fold).toBeDefined()

    describe "when a fold-all event is triggered", ->
      it "creates folds on every line that can be folded", ->
        editor.setCursorBufferPosition([5,13])

        editor.trigger "fold-all"
        expect(editor.screenLineForRow(0).fold).toBeDefined()
        expect(editor.screenLineForRow(1)).toBeUndefined()

      it "maintains cursor buffer position when a fold is created/destroyed", ->
        editor.setCursorBufferPosition([5,5])
        editor.trigger "fold-all"
        expect(editor.getCursorBufferPosition()).toEqual([5,5])

  describe "primitive folding", ->
    beforeEach ->
      editor.setBuffer(new Buffer(require.resolve('fixtures/two-hundred.txt')))
      editor.attachToDom()

    describe "when a fold-selection event is triggered", ->
      it "folds the lines covered by the selection into a single line with a fold class", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'fold-selection'

        expect(editor.renderedLines.find('.line:eq(4)')).toHaveClass('fold')
        expect(editor.renderedLines.find('.line:eq(5)').text()).toBe '8'

        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.getCursorScreenPosition()).toEqual [5, 0]

    describe "when a fold placeholder line is clicked", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.getSelection().setBufferRange(new Range([3, 0], [9, 0]))
        editor.trigger 'fold-selection'

        editor.find('.fold.line').mousedown()

        expect(editor.find('.fold')).not.toExist()
        expect(editor.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editor.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when the unfold event is triggered when the cursor is on a fold placeholder line", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.getSelection().setBufferRange(new Range([3, 0], [9, 0]))
        editor.trigger 'fold-selection'

        editor.setCursorBufferPosition([3,0])
        editor.trigger 'unfold'

        expect(editor.find('.fold')).not.toExist()
        expect(editor.renderedLines.find('.line:eq(4)').text()).toMatch /4-+/
        expect(editor.renderedLines.find('.line:eq(5)').text()).toMatch /5/

        expect(editor.getCursorBufferPosition()).toEqual [3, 0]

    describe "when a selection starts/stops intersecting a fold", ->
      it "adds/removes the 'selected' class to the fold's line element and hides the cursor if it is on the fold line", ->
        editor.createFold(2, 4)

        editor.setSelectionBufferRange([[1, 0], [2, 0]], reverse: true)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

        editor.setSelectionBufferRange([[1, 0], [1, 1]])
        expect(editor.lineElementForScreenRow(2)).not.toMatchSelector('.fold.selected')

        editor.setSelectionBufferRange([[1, 0], [5, 0]])
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
        editor.setSelectionBufferRange([[1, 0], [5, 0]])
        expect(editor.renderedLines.find('.fold.selected')).toExist()

        editor.scrollToBottom()
        expect(editor.renderedLines.find('.fold.selected')).not.toExist()

        editor.scrollTop(0)
        expect(editor.lineElementForScreenRow(2)).toMatchSelector('.fold.selected')

  describe "editor-path-change event", ->
    it "emits event when buffer's path is changed", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor-path-change', eventHandler
      editor.buffer.setPath("moo.text")

    it "emits event when editor receives a new buffer", ->
      eventHandler = jasmine.createSpy('eventHandler')
      editor.on 'editor-path-change', eventHandler
      editor.setBuffer(new Buffer("something.txt"))
      expect(eventHandler).toHaveBeenCalled()

    it "stops listening to events on previously set buffers", ->
      eventHandler = jasmine.createSpy('eventHandler')
      oldBuffer = editor.buffer
      editor.on 'editor-path-change', eventHandler

      editor.setBuffer(new Buffer("something.txt"))
      expect(eventHandler).toHaveBeenCalled()

      eventHandler.reset()
      oldBuffer.setPath("bad.txt")
      expect(eventHandler).not.toHaveBeenCalled()

      eventHandler.reset()
      editor.buffer.setPath("new.txt")
      expect(eventHandler).toHaveBeenCalled()

  describe "split methods", ->
    describe "when inside a pane", ->
      fakePane = null
      beforeEach ->
        fakePane = { splitUp: jasmine.createSpy('splitUp').andReturn({}), remove: -> }
        spyOn(editor, 'pane').andReturn(fakePane)

      it "calls the corresponding split method on the containing pane with a copy of the editor", ->
        editor.splitUp()
        expect(fakePane.splitUp).toHaveBeenCalled()
        [editorCopy] = fakePane.splitUp.argsForCall[0]
        expect(editorCopy.serialize()).toEqual editor.serialize()
        expect(editorCopy).not.toBe editor
        editorCopy.remove()

    describe "when not inside a pane", ->
      it "does not split the editor, but doesn't throw an exception", ->
        editor.splitUp()
        editor.splitDown()
        editor.splitLeft()
        editor.splitRight()

  describe "when 'close' is triggered", ->
    it "closes active edit session and loads next edit session", ->
      editor.setBuffer(new Buffer())
      spyOn(editor, "remove")
      editor.trigger "close"
      expect(editor.remove).not.toHaveBeenCalled()
      expect(editor.buffer).toBe buffer

    it "calls remove on the editor if there is one edit session and mini is false", ->
      originalBuffer = editor.buffer
      expect(editor.mini).toBeFalsy()
      expect(editor.editSessions.length).toBe 1
      spyOn(editor, 'remove')
      editor.trigger 'close'
      expect(editor.remove).toHaveBeenCalled()

      editor.remove()
      editor = new Editor(mini: true)
      spyOn(editor, 'remove')
      editor.trigger 'close'
      expect(editor.remove).not.toHaveBeenCalled()

    describe "when buffer is modified", ->
      it "triggers alert and does not close session", ->
        spyOn(editor, 'remove')
        spyOn($native, 'alert')
        editor.insertText("I AM CHANGED!")
        editor.trigger "close"
        expect(editor.remove).not.toHaveBeenCalled()
        expect($native.alert).toHaveBeenCalled()
