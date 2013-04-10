GitDiffView = require './git-diff-view'

module.exports =
  configDefaults:
    enabled: false

  activate: ->
    return unless git?
    return unless config.get('git-diff.enabled')

    rootView.eachEditor (editor) =>
      new GitDiffView(editor) if git? and editor.getPane()?
