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

  profile "inserting and deleting a character", ->
    editor.hiddenInput.textInput('x')
    editor.backspace()

