SpellCheckView = require './spell-check-view'

module.exports =
  configDefaults:
    grammars: [
      'text.plain'
      'source.gfm'
      'text.git-commit'
    ]

  activate: ->
    rootView.eachEditor (editor) ->
      if editor.attached and not editor.mini
        editor.underlayer.append(new SpellCheckView(editor))

  deactivate: ->
    syntax.off '.spell-check'
