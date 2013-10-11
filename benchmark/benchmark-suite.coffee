require './benchmark-helper'
{$, _, RootView} = require 'atom'
TokenizedBuffer = require '../src/tokenized-buffer'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.rootView = new RootView
    window.rootView.attachToDom()

    rootView.width(1024)
    rootView.height(768)
    rootView.openSync() # open blank editor
    editor = rootView.getActiveView()

  afterEach ->
    if editor.pendingDisplayUpdate
      waitsFor "editor to finish rendering", (done) ->
        editor.on 'editor:display-updated', done

  describe "keymap.", ->
    event = null

    beforeEach ->
      event = keydownEvent('x', target: editor.hiddenInput[0])

    benchmark "keydown-event-with-no-binding", 10, ->
      keymap.handleKeyEvent(event)

  describe "opening-buffers.", ->
    benchmark "300-line-file.", ->
      buffer = project.bufferForPath('medium.coffee')

  describe "empty-file.", ->
    benchmark "insert-delete", ->
      editor.insertText('x')
      editor.backspace()

  describe "300-line-file.", ->
    beforeEach ->
      rootView.openSync('medium.coffee')

    describe "at-begining.", ->
      benchmark "insert-delete", ->
        editor.insertText('x')
        editor.backspace()

      benchmark "insert-delete-rehighlight", ->
        editor.insertText('"')
        editor.backspace()

    describe "at-end.", ->
      beforeEach ->
        editor.moveCursorToBottom()

      benchmark "insert-delete", ->
        editor.insertText('"')
        editor.backspace()

    describe "empty-vs-set-innerHTML.", ->
      [firstRow, lastRow] = []
      beforeEach ->
        firstRow = editor.getFirstVisibleScreenRow()
        lastRow = editor.getLastVisibleScreenRow()

      benchmark "build-gutter-html.", 1000, ->
        editor.gutter.renderLineNumbers(null, firstRow, lastRow)

      benchmark "set-innerHTML.", 1000, ->
        editor.gutter.renderLineNumbers(null, firstRow, lastRow)
        editor.gutter.lineNumbers[0].innerHtml = ''

      benchmark "empty.", 1000, ->
        editor.gutter.renderLineNumbers(null, firstRow, lastRow)
        editor.gutter.lineNumbers.empty()

    describe "positionLeftForLineAndColumn.", ->
      line = null
      beforeEach ->
        editor.scrollTop(2000)
        editor.resetDisplay()
        line = editor.lineElementForScreenRow(106)[0]

      describe "one-line.", ->
        beforeEach ->
          editor.clearCharacterWidthCache()

        benchmark "uncached", 5000, ->
          editor.positionLeftForLineAndColumn(line, 106, 82)
          editor.clearCharacterWidthCache()

        benchmark "cached", 5000, ->
          editor.positionLeftForLineAndColumn(line, 106, 82)

      describe "multiple-lines.", ->
        [firstRow, lastRow] = []
        beforeEach ->
          firstRow = editor.getFirstVisibleScreenRow()
          lastRow = editor.getLastVisibleScreenRow()

        benchmark "cache-entire-visible-area", 100, ->
          for i in [firstRow..lastRow]
            line = editor.lineElementForScreenRow(i)[0]
            editor.positionLeftForLineAndColumn(line, i, Math.max(0, editor.lineLengthForBufferRow(i)))

    describe "text-rendering.", ->
      beforeEach ->
        editor.scrollTop(2000)

      benchmark "resetDisplay", 50, ->
        editor.resetDisplay()

      benchmark "htmlForScreenRows", 1000, ->
        lastRow = editor.getLastScreenRow()
        editor.htmlForScreenRows(0, lastRow)

      benchmark "htmlForScreenRows.htmlParsing", 50, ->
        lastRow = editor.getLastScreenRow()
        html = editor.htmlForScreenRows(0, lastRow)

        div = document.createElement('div')
        div.innerHTML = html

    describe "gutter-api.", ->
      describe "getLineNumberElementsForClass.", ->
        beforeEach ->
          editor.gutter.addClassToLine(20, 'omgwow')
          editor.gutter.addClassToLine(40, 'omgwow')

        benchmark "DOM", 20000, ->
          editor.gutter.getLineNumberElementsForClass('omgwow')

      benchmark "getLineNumberElement.DOM", 20000, ->
        editor.gutter.getLineNumberElement(12)

      benchmark "toggle-class", 2000, ->
        editor.gutter.addClassToLine(40, 'omgwow')
        editor.gutter.removeClassFromLine(40, 'omgwow')

      describe "find-then-unset.", ->
        classes = ['one', 'two', 'three', 'four']

        benchmark "single-class", 200, ->
          editor.gutter.addClassToLine(30, 'omgwow')
          editor.gutter.addClassToLine(40, 'omgwow')
          editor.gutter.removeClassFromAllLines('omgwow')

        benchmark "multiple-class", 200, ->
          editor.gutter.addClassToLine(30, 'one')
          editor.gutter.addClassToLine(30, 'two')

          editor.gutter.addClassToLine(40, 'two')
          editor.gutter.addClassToLine(40, 'three')
          editor.gutter.addClassToLine(40, 'four')

          for klass in classes
            editor.gutter.removeClassFromAllLines(klass)

    describe "line-htmlification.", ->
      div = null
      html = null
      beforeEach ->
        lastRow = editor.getLastScreenRow()
        html = editor.htmlForScreenRows(0, lastRow)
        div = document.createElement('div')

      benchmark "setInnerHTML", 1, ->
        div.innerHTML = html

  describe "9000-line-file.", ->
    benchmark "opening.", 5, ->
      rootView.openSync('huge.js')

    describe "after-opening.", ->
      beforeEach ->
        rootView.openSync('huge.js')

      benchmark "moving-to-eof.", 1, ->
        editor.moveCursorToBottom()

      describe "on-first-line.", ->
        benchmark "inserting-newline", 5, ->
          editor.insertNewline()

      describe "on-last-visible-line.", ->
        beforeEach ->
          editor.setCursorScreenPosition([editor.getLastVisibleScreenRow(), 0])

        benchmark "move-down-and-scroll", 300, ->
          editor.trigger 'move-down'

      describe "at-eof.", ->
        endPosition = null

        beforeEach ->
          editor.moveCursorToBottom()
          endPosition = editor.getCursorScreenPosition()

        benchmark "move-to-beginning-of-word", ->
          editor.moveCursorToBeginningOfWord()
          editor.setCursorScreenPosition(endPosition)

        benchmark "insert", ->
          editor.insertText('x')

describe "TokenizedBuffer.", ->
  describe "coffee-script-grammar.", ->
    [languageMode, buffer] = []

    beforeEach ->
      editSession = benchmarkFixturesProject.openSync('medium.coffee')
      { languageMode, buffer } = editSession

    benchmark "construction", 20, ->
      new TokenizedBuffer(buffer, { languageMode, tabLength: 2})
