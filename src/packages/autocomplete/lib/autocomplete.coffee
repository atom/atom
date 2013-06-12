AutocompleteView = require './autocomplete-view'

module.exports =
  autoCompleteViews: []
  editorSubscription: null

  activate: ->
    @editorSubscription = rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        @autoCompleteViews.push new AutocompleteView(editor)

  deactivate: ->
    @editorSubscription?.off()
    @editorSubscription = null
    @autoCompleteViews.forEach (autoCompleteView) -> autoCompleteView.remove()
    @autoCompleteViews = []
