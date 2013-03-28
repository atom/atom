SpellCheckView = require './spell-check-view'

module.exports =
  configDefaults:
    grammars: [
      'text.plain'
      'source.gfm'
      'text.git-commit'
    ]

  activate: ->
    syntax.on 'grammars-loaded.spell-check', => @subscribeToEditors()

  deactivate: ->
    syntax.off '.spell-check'

  subscribeToEditors: ->
    rootView.eachEditor (editor) ->
      if editor.attached and not editor.mini
        editor.underlayer.append(new SpellCheckView(editor))
