_ = require 'underscore'
shell = require 'shell'

module.exports =
class BookmarksView
  @activate: ->
    rootView.eachEditor (editor) =>
      new BookmarksView(editor) if editor.attached and editor.getPane()?

  editor: null

  constructor: (@editor) ->
    @gutter = @editor.gutter
    @editor.on 'editor:display-updated', @renderBookmarkMarkers

    rootView.command 'bookmarks:toggle-bookmark', '.editor', @toggleBookmark
    rootView.command 'bookmarks:jump-to-next-bookmark', '.editor', @jumpToNextBookmark
    rootView.command 'bookmarks:jump-to-previous-bookmark', '.editor', @jumpToPreviousBookmark

  toggleBookmark: =>
    cursors = @editor.getCursors()
    for cursor in cursors
      position = cursor.getBufferPosition()
      bookmarks = @findBookmarkMarkers(startBufferRow: position.row)

      if bookmarks and bookmarks.length
        bookmark.destroy() for bookmark in bookmarks
      else
        newmark = @createBookmarkMarker(position.row)

    @renderBookmarkMarkers()

  jumpToNextBookmark: =>
    @jumpToBookmark('getNextBookmark')

  jumpToPreviousBookmark: =>
    @jumpToBookmark('getPreviousBookmark')

  renderBookmarkMarkers: =>
    return unless @gutter.isVisible()

    @gutter.find(".line-number.bookmarked").removeClass('bookmarked')

    markers = @findBookmarkMarkers()
    for marker in markers
      row = marker.getBufferRange().start.row
      @gutter.find(".line-number[lineNumber=#{row}]").addClass('bookmarked')

  ### Internal ###

  jumpToBookmark: (getBookmarkFunction) =>
    cursor = @editor.getCursor()
    position = cursor.getBufferPosition()
    bookmarkMarker = @[getBookmarkFunction](position.row)

    if bookmarkMarker
      @editor.activeEditSession.setSelectedBufferRange(bookmarkMarker.getBufferRange(), autoscroll: true)
    else
      shell.beep()

  getPreviousBookmark: (bufferRow) ->
    markers = @findBookmarkMarkers()
    return null unless markers.length

    bookmarkIndex = _.sortedIndex markers, bufferRow, (marker) ->
      if marker.getBufferRange then marker.getBufferRange().start.row else marker

    bookmarkIndex--
    bookmarkIndex = markers.length - 1 if bookmarkIndex < 0

    markers[bookmarkIndex]

  getNextBookmark: (bufferRow) ->
    markers = @findBookmarkMarkers()
    return null unless markers.length

    bookmarkIndex = _.sortedIndex markers, bufferRow, (marker) ->
      if marker.getBufferRange then marker.getBufferRange().start.row else marker

    bookmarkIndex++ if markers[bookmarkIndex].getBufferRange().start.row == bufferRow
    bookmarkIndex = 0 if bookmarkIndex >= markers.length

    markers[bookmarkIndex]

  createBookmarkMarker: (bufferRow) ->
    range = [[bufferRow, 0], [bufferRow, 0]]
    @displayBuffer().markBufferRange(range, @bookmarkMarkerAttributes(invalidationStrategy: 'never'))

  findBookmarkMarkers: (attributes={}) ->
    @displayBuffer().findMarkers(@bookmarkMarkerAttributes(attributes))

  bookmarkMarkerAttributes: (attributes={}) ->
    _.extend(attributes, class: 'bookmark', displayBufferId: @displayBuffer().id)

  displayBuffer: ->
    @editor.activeEditSession.displayBuffer
