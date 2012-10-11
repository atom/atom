module.exports =
class LowerCaseCommand

  @activate: (rootView) ->
    rootView.eachEditor(@onEditor)

  @onEditor: (editor) ->
    editor.bindToKeyedEvent 'meta-Y', 'lowercase', ->
      editor.replaceSelectedText (text) ->
        text.toLowerCase()
