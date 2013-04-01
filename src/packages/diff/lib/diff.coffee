$ = require 'jquery'
EditSession = require 'edit-session'
{View, $$} = require 'space-pen'
diff = require 'diff'
DiffView = require 'diff/lib/diff-view'

module.exports =
class Diff extends View
  @activate: -> new Diff

  constructor: ->
    rootView.command 'diff:toggle-diff', '.editor', => @toggleDiff()

  toggleDiff: ->
    console.log(@active)
    if @active
      @hideDiff()
    else
      @active = true
      @showDiff()

  showDiff: ->
    @activePane = rootView.getActivePane()
    @item = @activePane.activeItem

    if not @item instanceof EditSession
      console.warn("Can not render diff for #{item.getUri()}")
      return

    buffer = @item.buffer
    path = buffer.file.path

    @diskContents = buffer.cachedDiskContents

    changes = diff.diffWords(git.getHeadBlob(path), @diskContents)

    @activePane.showItem(new DiffView(buffer, @convertChanges(changes)))

  hideDiff: ->
    @activePane.showItem(@item)
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


  destroy: ->
    @hideDiff()
