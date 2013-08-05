path = require 'path'

{$$} = require 'space-pen'

SelectList = require 'select-list'

module.exports =
class BookmarksView extends SelectList
  @viewClass: -> "#{super} bookmarks-view overlay from-top"

  filterKey: 'bookmarkFilterText'

  initialize: ->
    super

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @populateBookmarks()
      @attach()

  getFilterText: (bookmark) ->
    segments = []
    bookmarkRow = bookmark.getStartPosition().row
    segments.push(bookmarkRow)
    if bufferPath = bookmark.buffer.getPath()
      segments.push(bufferPath)
    if lineText = @getLineText(bookmark)
      segments.push(lineText)
    segments.join(' ')

  getLineText: (bookmark) ->
    bookmark.buffer.lineForRow(bookmark.getStartPosition().row)?.trim()

  populateBookmarks: ->
    markers = []
    attributes = class: 'bookmark'
    for buffer in project.getBuffers()
      for marker in buffer.findMarkers(attributes)
        marker.bookmarkFilterText = @getFilterText(marker)
        markers.push(marker)
    @setArray(markers)

  itemForElement: (bookmark) ->
    bookmarkRow = bookmark.getStartPosition().row
    if filePath = bookmark.buffer.getPath()
      bookmarkLocation = "#{path.basename(filePath)}:#{bookmarkRow + 1}"
    else
      bookmarkLocation = "untitled:#{bookmarkRow + 1}"
    lineText = @getLineText(bookmark)

    $$ ->
      if lineText
        @li class: 'bookmark two-lines', =>
          @div bookmarkLocation, class: 'primary-line'
          @div lineText, class: 'secondary-line line-text'
      else
        @li class: 'bookmark', =>
          @div bookmarkLocation, class: 'primary-line'

  getEmptyMessage: (itemCount) ->
    if itemCount is 0
      'No bookmarks found'
    else
      super

  confirmed : (bookmark) ->
    for editor in rootView.getEditors()
      if editor.getBuffer() is bookmark.buffer
        editor.activeEditSession.setSelectedBufferRange(bookmark.getRange(), autoscroll: true)

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()
