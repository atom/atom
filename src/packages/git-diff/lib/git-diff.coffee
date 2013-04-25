GitDiffView = require './git-diff-view'

module.exports =
  activate: ->
    return unless git?

    rootView.eachEditor (editor) =>
      new GitDiffView(editor) if git? and editor.attached and editor.getPane()?
