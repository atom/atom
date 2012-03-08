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

  benchmark "inserting and deleting a character", ->
    editor.insertText('x')
    editor.backspace()

