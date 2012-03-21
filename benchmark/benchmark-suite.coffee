Buffer = require 'buffer'
fs = require 'fs'
require 'benchmark-helper'

describe "editor.", ->
  editor = null

  beforeEach ->
    window.rootViewParentSelector = '#jasmine-content'
    window.startup()
    editor = rootView.activeEditor()

  afterEach ->
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
        editor.setCursorScreenPosition([Infinity, Infinity])

      benchmark "insert-delete", ->
        editor.insertText('"')
        editor.backspace()


