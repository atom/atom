$ = require 'jquery'
{View, $$} = require 'space-pen'
diff = require 'diff'

module.exports =
class Diff extends View
  @activate: -> new Diff

  constructor: ->
    rootView.command 'diff:toggle-diff', '.editor', => @toggleDiff()

  toggleDiff: ->
    if @active
      @hideDiff()
    else
      @active = true
      @showDiff()

  showDiff: ->
    @editor = rootView.getActiveView()
    return unless @editor?
    
    buffer = @editor.getBuffer()
    path = buffer.file.path

    @diskContents = buffer.cachedDiskContents

    changes = diff.diffWords(@diskContents, git.getHeadBlob(path))
    result = @convertChanges(changes)

    @editor.setText(result)

  hideDiff: ->
    @editor.setText(@diskContents)
    @active = false

  convertChanges: (changes) ->
    ret = []
    changesLength = changes.length

    for change in changes
      if (change.added)
        ret.push("<ins>")
      else if (change.removed)
        ret.push("<del>")

      ret.push(change.value)

      if (change.added)
        ret.push("</ins>")
      else if (change.removed)
        ret.push("</del>")

    return ret.join("");

