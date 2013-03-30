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
    # if @active
    #   @hideDiff()
    # else
    #   @active = true
    #   @showDiff()

  showDiff: ->
    # @activePane = rootView.getActivePane()
    # @item = @activePane.activeItem

    # if not @item instanceof EditSession
    #   console.warn("Can not render markdown for #{item.getUri()}")
    #   return

    # editSession = @item

    #@activePane.showItem(new DiffView(editSession.buffer))
    # buffer = @editor.getBuffer()
    # path = buffer.file.path

    # @diskContents = buffer.cachedDiskContents

    # changes = diff.diffWords(@diskContents, git.getHeadBlob(path))
    # result = @convertChanges(changes)

    # @editor.setText(result)

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
