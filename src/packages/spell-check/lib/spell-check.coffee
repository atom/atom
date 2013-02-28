SpellCheckView = require './spell-check-view'

module.exports =
  configDefaults:
    grammars: [
      'text.plain'
      'source.gfm'
      'text.git-commit'
    ]

  activate: ->
    if syntax.grammars.length > 1
      @subscribeToEditors()
    else
      syntax.on 'grammars-loaded', => @subscribeToEditors()

  subscribeToEditors: ->
    rootView.eachEditor (editor) ->
      if editor.attached and not editor.mini
        editor.underlayer.append(new SpellCheckView(editor))
