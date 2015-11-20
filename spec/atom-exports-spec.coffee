{isTextEditor} = require 'atom'

describe "atom exports", ->
  describe "::isTextEditor(obj)", ->
    it "returns true when the passed object is an instance of `TextEditor`", ->
      expect(isTextEditor(atom.workspace.buildTextEditor())).toBe(true)
      expect(isTextEditor({getText: ->})).toBe(false)
