Buffer = require 'buffer'
fs = require 'fs'
require 'benchmark-helper'
$ = require 'jquery'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.startup()
    editor = rootView.activeEditor()

  afterEach ->
    $(window).off 'beforeunload'
    window.shutdown()

  describe "empty-file.", ->
    benchmark "insert-delete", ->
      editor.insertText('x')
      editor.backspace()

  describe "300-line-file.", ->
    beforeEach ->
      editor.setBuffer new Buffer(require.resolve('fixtures/medium.coffee'))

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
    benchmark "opening.", 1, ->
      editor.setBuffer new Buffer(require.resolve('fixtures/huge.js'))

    describe "after-opening.", ->
      beforeEach ->
        editor.setBuffer new Buffer(require.resolve('fixtures/huge.js'))

      benchmark "moving-to-eof.", 1, ->
        editor.moveCursorToBottom()
        waitsFor (scrollComplete) ->
          editor.scroller.on 'scroll', scrollComplete

      describe "at-eof.", ->
        endPosition = null

        beforeEach ->
          editor.moveCursorToBottom()
          endPosition = editor.getCursorScreenPosition()

        benchmark "move-to-beginning-of-word", ->
          editor.moveCursorToBeginningOfWord()
          editor.setCursorScreenPosition(endPosition)
