$ = require 'jquery'
{$$} = require 'space-pen'

module.exports =
class Gists
  @activate: -> new Gists

  constructor: ->
    rootView.command 'diff:toggle-diff', '.editor', => @showDiff()

  showDiff: ->
    editor = rootView.getActiveView()
    return unless editor?

    console.log(editor)
    console.log("yeah")