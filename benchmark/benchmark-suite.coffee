Buffer = require 'buffer'
fs = require 'fs'
require 'benchmark-helper'

describe "Editor", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.startup()
    editor = rootView.editor

  afterEach ->
    window.shutdown()

  benchmark "inserting and deleting a character in an empty file", ->
    editor.insertText('x')
    editor.backspace()

  describe "when editing a ~300 line CoffeeScript file", ->
    beforeEach ->
      editor.setBuffer new Buffer(require.resolve('fixtures/medium.coffee'))

    describe "when the cursor is at the beginning of the file", ->
      benchmark "inserting and deleting a character at the beginning of the file", ->
        editor.insertText('x')
        editor.backspace()

      benchmark "inserting and deleting a character that causes massive re-highlighting", ->
        editor.insertText('"')
        editor.backspace()

    describe "when the cursor is at the end of the file", ->
      beforeEach ->
        editor.setCursorScreenPosition([Infinity, Infinity])

      benchmark "inserting and deleting a character", ->
        editor.insertText('"')
        editor.backspace()


