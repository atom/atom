module.exports =
  configDefaults:
    grammars: [
      'text.plain'
      'source.gfm'
      'text.git-commit'
    ]

  createView: (editor) ->
    @spellCheckViewClass ?= require './spell-check-view'
    new @spellCheckViewClass(editor)

  activate: ->
    rootView.eachEditor (editor) =>
      editor.underlayer.append(@createView(editor)) if editor.getPane()?
