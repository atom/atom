module.exports =
class LowerCaseCommand

  @activate: (rootView) ->
    rootView.eachEditor (editor) ->
      editor.bindToKeyedEvent 'meta-Y', 'lowercase', ->
        editor.replaceSelectedText (text) ->
          text.toLowerCase()
