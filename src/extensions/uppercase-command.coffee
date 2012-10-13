module.exports =
class UpperCaseCommand

  @activate: (rootView) ->
    rootView.eachEditor (editor) ->
      editor.bindToKeyedEvent 'meta-X', 'uppercase', ->
        editor.replaceSelectedText (text) ->
          text.toUpperCase()
