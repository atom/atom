_ = require 'underscore'

module.exports =
class BookmarksView
  @activate: ->
    rootView.eachEditor (editor) =>
      new BookmarksView(editor) if editor.attached and editor.getPane()?

  editor: null

  constructor: (@editor) ->
    @editor.on 'editor:display-updated', @updateBookmarkedLines

    rootView.command 'bookmarks:toggle-bookmark', '.editor', @toggleBookmark
    rootView.command 'bookmarks:jump-to-next-bookmark', '.editor', @jumpToNextBookmark
    rootView.command 'bookmarks:jump-to-previous-bookmark', '.editor', @jumpToPreviousBookmark

  toggleBookmark: =>
    cursors = @editor.getCursors()
    for cursor in cursors
      position = cursor.getBufferPosition()
      bookmarks = @findBookmarkMarkers(position.row)

      if bookmarks and bookmarks.length
        bookmark.destroy() for bookmark in bookmarks
        console.log('removing mark', position, bookmark)
      else
        newmark = @createBookmarkMarker(position.row)
        console.log('bookmarking', position, newmark)

  updateBookmarkedLines: =>
    console.log('update!', @editor)

  jumpToNextBookmark: =>
    console.log('next bm', @editor)

  jumpToPreviousBookmark: =>
    console.log('prev bm', @editor)


  ### Internal ###

  createBookmarkMarker: (bufferRow) ->
    range = [[bufferRow, 0], [bufferRow, 0]]
    @displayBuffer().markBufferRange(range, @bookmarkMarkerAttributes(invalidationStrategy: 'never'))

  findBookmarkMarkers: (bufferRow) ->
    @displayBuffer().findMarkers(@bookmarkMarkerAttributes(startBufferRow: bufferRow))

  bookmarkMarkerAttributes: (attributes={}) ->
    _.extend(attributes, class: 'bookmark', displayBufferId: @displayBuffer().id)

  displayBuffer: ->
    @editor.activeEditSession.displayBuffer
