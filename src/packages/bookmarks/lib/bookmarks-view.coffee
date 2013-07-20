_ = require 'underscore'

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
        console.log('removing mark', position, bookmark)
      else
        newmark = @createBookmarkMarker(position.row)
        console.log('bookmarking', position, newmark)

    @renderBookmarkMarkers()

  jumpToNextBookmark: =>
    console.log('next bm', @editor)

  jumpToPreviousBookmark: =>
    console.log('prev bm', @editor)

  renderBookmarkMarkers: =>
    return unless @gutter.isVisible()

    @gutter.find(".line-number.bookmarked").removeClass('bookmarked')

    markers = @findBookmarkMarkers()
    for marker in markers
      row = marker.getBufferRange().start.row
      @gutter.find(".line-number[lineNumber=#{row}]").addClass('bookmarked')

  ### Internal ###

  createBookmarkMarker: (bufferRow) ->
    range = [[bufferRow, 0], [bufferRow, 0]]
    @displayBuffer().markBufferRange(range, @bookmarkMarkerAttributes(invalidationStrategy: 'never'))

  findBookmarkMarkers: (attributes={}) ->
    @displayBuffer().findMarkers(@bookmarkMarkerAttributes(attributes))

  bookmarkMarkerAttributes: (attributes={}) ->
    _.extend(attributes, class: 'bookmark', displayBufferId: @displayBuffer().id)

  displayBuffer: ->
    @editor.activeEditSession.displayBuffer
