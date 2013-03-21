require 'benchmark-helper'
fs = require 'fs-utils'
$ = require 'jquery'
_ = require 'underscore'
TokenizedBuffer = require 'tokenized-buffer'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.attachRootView(require.resolve('benchmark/fixtures'))

    rootView.width(1024)
    rootView.height(768)
    rootView.open() # open blank editor
    editor = rootView.getActiveEditor()

  afterEach ->
    if editor.pendingDisplayUpdate
      waitsFor "editor to finish rendering", (done) ->
        editor.on 'editor:display-updated', done

    runs ->
      projectPath = project.getPath()
      $(window).off 'beforeunload'
      window.shutdown()
      atom.setRootViewStateForPath(projectPath, null)

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
      rootView.open('medium.coffee')

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

  describe "9000-line-file.", ->
    benchmark "opening.", 5, ->
      rootView.open('huge.js')

    describe "after-opening.", ->
      beforeEach ->
        rootView.open('huge.js')

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
      editSession = benchmarkFixturesProject.buildEditSession('medium.coffee')
      { languageMode, buffer } = editSession

    benchmark "construction", 20, ->
      new TokenizedBuffer(buffer, { languageMode, tabLength: 2})
