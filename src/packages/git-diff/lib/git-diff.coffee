GitDiffView = require './git-diff-view'

module.exports =
  activate: ->
    rootView.eachEditor (editor) =>
      new GitDiffView(editor) if project.getRepo()? and editor.attached and editor.getPane()?
