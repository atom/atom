module.exports =
class UpperCaseCommand

  @activate: (rootView) ->
    rootView.eachEditor(@onEditor)

  @onEditor: (editor) ->
    editor.bindToKeyedEvent 'meta-X', 'uppercase', =>
      editor.replaceSelectedText (text) ->
        text.toUpperCase()
