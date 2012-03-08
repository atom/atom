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

  fdescribe "when editing a ~300 line CoffeeScript file", ->
    beforeEach ->
      editor.setBuffer new Buffer(require.resolve('fixtures/medium.coffee'))

    benchmark "inserting and deleting a character", ->
      editor.insertText('x')
      editor.backspace()

