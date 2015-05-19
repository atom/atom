require './benchmark-helper'
{$} = require '../src/space-pen-extensions'
_ = require 'underscore-plus'
{WorkspaceView} = require 'atom'
TokenizedBuffer = require '../src/tokenized-buffer'

describe "editorView.", ->
  editorView = null

  beforeEach ->
    atom.workspaceViewParentSelector = '#jasmine-content'
    atom.workspaceView = atom.views.getView(atom.workspace).__spacePenView
    atom.workspaceView.attachToDom()

    atom.workspaceView.width(1024)
    atom.workspaceView.height(768)
    atom.workspaceView.openSync()
    editorView = atom.workspaceView.getActiveView()

  afterEach ->
    if editorView.pendingDisplayUpdate
      waitsFor "editor to finish rendering", (done) ->
        editorView.on 'editor:display-updated', done

  describe "keymap.", ->
    event = null

    beforeEach ->
      event = keydownEvent('x', target: editorView.hiddenInput[0])

    benchmark "keydown-event-with-no-binding", 10, ->
      keymap.handleKeyEvent(event)

  describe "opening-buffers.", ->
    benchmark "300-line-file.", ->
      buffer = project.bufferForPathSync('medium.coffee')

  describe "empty-file.", ->
    benchmark "insert-delete", ->
      editorView.insertText('x')
      editorView.backspace()

  describe "300-line-file.", ->
    beforeEach ->
      atom.workspaceView.openSync('medium.coffee')

    describe "at-begining.", ->
      benchmark "insert-delete", ->
        editorView.insertText('x')
        editorView.backspace()

      benchmark "insert-delete-rehighlight", ->
        editorView.insertText('"')
        editorView.backspace()

    describe "at-end.", ->
      beforeEach ->
        editorView.moveToBottom()

      benchmark "insert-delete", ->
        editorView.insertText('"')
        editorView.backspace()

    describe "empty-vs-set-innerHTML.", ->
      [firstRow, lastRow] = []
      beforeEach ->
        firstRow = editorView.getModel().getFirstVisibleScreenRow()
        lastRow = editorView.getModel().getLastVisibleScreenRow()

      benchmark "build-gutter-html.", 1000, ->
        editorView.gutter.renderLineNumbers(null, firstRow, lastRow)

      benchmark "set-innerHTML.", 1000, ->
        editorView.gutter.renderLineNumbers(null, firstRow, lastRow)
        editorView.gutter.lineNumbers[0].innerHtml = ''

      benchmark "empty.", 1000, ->
        editorView.gutter.renderLineNumbers(null, firstRow, lastRow)
        editorView.gutter.lineNumbers.empty()

    describe "positionLeftForLineAndColumn.", ->
      line = null
      beforeEach ->
        editorView.scrollTop(2000)
        editorView.resetDisplay()
        line = editorView.lineElementForScreenRow(106)[0]

      describe "one-line.", ->
        beforeEach ->
          editorView.clearCharacterWidthCache()

        benchmark "uncached", 5000, ->
          editorView.positionLeftForLineAndColumn(line, 106, 82)
          editorView.clearCharacterWidthCache()

        benchmark "cached", 5000, ->
          editorView.positionLeftForLineAndColumn(line, 106, 82)

      describe "multiple-lines.", ->
        [firstRow, lastRow] = []
        beforeEach ->
          firstRow = editorView.getModel().getFirstVisibleScreenRow()
          lastRow = editorView.getModel().getLastVisibleScreenRow()

        benchmark "cache-entire-visible-area", 100, ->
          for i in [firstRow..lastRow]
            line = editorView.lineElementForScreenRow(i)[0]
            editorView.positionLeftForLineAndColumn(line, i, Math.max(0, editorView.getModel().lineTextForBufferRow(i).length))

    describe "text-rendering.", ->
      beforeEach ->
        editorView.scrollTop(2000)

      benchmark "resetDisplay", 50, ->
        editorView.resetDisplay()

      benchmark "htmlForScreenRows", 1000, ->
        lastRow = editorView.getLastScreenRow()
        editorView.htmlForScreenRows(0, lastRow)

      benchmark "htmlForScreenRows.htmlParsing", 50, ->
        lastRow = editorView.getLastScreenRow()
        html = editorView.htmlForScreenRows(0, lastRow)

        div = document.createElement('div')
        div.innerHTML = html

    describe "gutter-api.", ->
      describe "getLineNumberElementsForClass.", ->
        beforeEach ->
          editorView.gutter.addClassToLine(20, 'omgwow')
          editorView.gutter.addClassToLine(40, 'omgwow')

        benchmark "DOM", 20000, ->
          editorView.gutter.getLineNumberElementsForClass('omgwow')

      benchmark "getLineNumberElement.DOM", 20000, ->
        editorView.gutter.getLineNumberElement(12)

      benchmark "toggle-class", 2000, ->
        editorView.gutter.addClassToLine(40, 'omgwow')
        editorView.gutter.removeClassFromLine(40, 'omgwow')

      describe "find-then-unset.", ->
        classes = ['one', 'two', 'three', 'four']

        benchmark "single-class", 200, ->
          editorView.gutter.addClassToLine(30, 'omgwow')
          editorView.gutter.addClassToLine(40, 'omgwow')
          editorView.gutter.removeClassFromAllLines('omgwow')

        benchmark "multiple-class", 200, ->
          editorView.gutter.addClassToLine(30, 'one')
          editorView.gutter.addClassToLine(30, 'two')

          editorView.gutter.addClassToLine(40, 'two')
          editorView.gutter.addClassToLine(40, 'three')
          editorView.gutter.addClassToLine(40, 'four')

          for klass in classes
            editorView.gutter.removeClassFromAllLines(klass)

    describe "line-htmlification.", ->
      div = null
      html = null
      beforeEach ->
        lastRow = editorView.getLastScreenRow()
        html = editorView.htmlForScreenRows(0, lastRow)
        div = document.createElement('div')

      benchmark "setInnerHTML", 1, ->
        div.innerHTML = html

  describe "9000-line-file.", ->
    benchmark "opening.", 5, ->
      atom.workspaceView.openSync('huge.js')

    describe "after-opening.", ->
      beforeEach ->
        atom.workspaceView.openSync('huge.js')

      benchmark "moving-to-eof.", 1, ->
        editorView.moveToBottom()

      describe "on-first-line.", ->
        benchmark "inserting-newline", 5, ->
          editorView.insertNewline()

      describe "on-last-visible-line.", ->
        beforeEach ->
          editorView.setCursorScreenPosition([editorView.getLastVisibleScreenRow(), 0])

        benchmark "move-down-and-scroll", 300, ->
          editorView.trigger 'move-down'

      describe "at-eof.", ->
        endPosition = null

        beforeEach ->
          editorView.moveToBottom()
          endPosition = editorView.getCursorScreenPosition()

        benchmark "move-to-beginning-of-word", ->
          editorView.moveToBeginningOfWord()
          editorView.setCursorScreenPosition(endPosition)

        benchmark "insert", ->
          editorView.insertText('x')

describe "TokenizedBuffer.", ->
  describe "coffee-script-grammar.", ->
    [languageMode, buffer] = []

    beforeEach ->
      editor = benchmarkFixturesProject.openSync('medium.coffee')
      {languageMode, buffer} = editor

    benchmark "construction", 20, ->
      new TokenizedBuffer(buffer, {languageMode, tabLength: 2})
