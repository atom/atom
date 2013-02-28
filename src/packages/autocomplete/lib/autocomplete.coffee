AutocompleteView = require './autocomplete-view'

module.exports =
  autoCompleteViews: []

  activate: ->
    rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        @autoCompleteViews.push new AutocompleteView(editor)
