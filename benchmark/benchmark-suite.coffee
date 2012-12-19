require 'benchmark-helper'
fs = require 'fs'
$ = require 'jquery'
_ = require 'underscore'
TokenizedBuffer = require 'tokenized-buffer'
TextMateBundle = require 'text-mate-bundle'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.attachRootView(require.resolve('benchmark/fixtures'))

    rootView.width(1024)
    rootView.height(768)
    require fs.join(config.configDirPath, "default-config")
    rootView.open() # open blank editor
    editor = rootView.getActiveEditor()

  afterEach ->
    $(window).off 'beforeunload'
    window.shutdown()
    atom.setRootViewStateForPath(rootView.project.getPath(), null)

  describe "keymap.", ->
    event = null

    beforeEach ->
      event = keydownEvent('x', target: editor.hiddenInput[0])

    benchmark "keydown-event-with-no-binding", 10, ->
      keymap.handleKeyEvent(event)

  describe "opening-buffers.", ->
    benchmark "300-line-file.", ->
      buffer = rootView.project.bufferForPath('medium.coffee')

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
      editSession = benchmarkFixturesProject.buildEditSessionForPath('medium.coffee')
      { languageMode, buffer } = editSession

    benchmark "construction", 20, ->
      new TokenizedBuffer(buffer, { languageMode, tabLength: 2})
