require 'benchmark-helper'
fs = require 'fs'
$ = require 'jquery'
TokenizedBuffer = require 'tokenized-buffer'
TextMateBundle = require 'text-mate-bundle'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.startup()
    rootView.project.setPath(require.resolve('benchmark/fixtures'))
    editor = rootView.getActiveEditor()

  afterEach ->
    $(window).off 'beforeunload'
    window.shutdown()
    delete atom.rootViewStates[$windowNumber]

  describe "opening-buffers.", ->
    benchmark "300-line-file.", ->
      buffer = rootView.project.bufferForPath('medium.coffee')

  describe "empty-file.", ->
    benchmark "insert-delete", ->
      editor.insertText('x')
      editor.backspace()

  describe "300-line-file.", ->
    beforeEach ->
      editor.edit rootView.project.buildEditSessionForPath('medium.coffee')

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
      editor.edit rootView.project.buildEditSessionForPath('huge.js')

    describe "after-opening.", ->
      beforeEach ->
        editor.edit rootView.project.buildEditSessionForPath('huge.js')

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

describe "TokenizedBuffer.", ->
  describe "coffee-script-grammar.", ->
    [languageMode, buffer] = []

    beforeEach ->
      editSession = benchmarkFixturesProject.buildEditSessionForPath('medium.coffee')
      { languageMode, buffer } = editSession

    benchmark "construction", ->
      new TokenizedBuffer(buffer, { languageMode, tabText: '  '})

describe "OnigRegExp.", ->
  [regex, line] = []

  beforeEach ->
    line = "  l.comment_matcher = new RegExp('^\\s*' + l.symbol + '\\s?')"
    regex = TextMateBundle.grammarForFileName('medium.coffee').initialRule.regex

  benchmark ".getCaptureTree", 10000, ->
    regex.getCaptureIndices(line, 22)

