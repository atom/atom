{Point, Range} = require 'telepath'
{View, $$} = require './space-pen-extensions'

# Internal:
module.exports =
class SelectionView extends View

  @content: ->
    @div class: 'selection'

  regions: null
  needsRemoval: false

  initialize: ({@editor, @selection} = {}) ->
    @regions = []
    @selection.on 'screen-range-changed', => @editor.requestDisplayUpdate()
    @selection.on 'destroyed', =>
      @needsRemoval = true
      @editor.requestDisplayUpdate()

    if @selection.marker.isRemote()
      @addClass("site-#{@selection.marker.getOriginSiteId()}")

  updateDisplay: ->
    @clearRegions()
    range = @getScreenRange()

    @trigger 'selection:changed'
    @editor.highlightFoldsContainingBufferRange(@getBufferRange())
    return if range.isEmpty()

    rowSpan = range.end.row - range.start.row

    if rowSpan == 0
      @appendRegion(1, range.start, range.end)
    else
      @appendRegion(1, range.start, null)
      if rowSpan > 1
        @appendRegion(rowSpan - 1, { row: range.start.row + 1, column: 0}, null)
      @appendRegion(1, { row: range.end.row, column: 0 }, range.end)

  appendRegion: (rows, start, end) ->
    { lineHeight, charWidth } = @editor
    css = @editor.pixelPositionForScreenPosition(start)
    css.height = lineHeight * rows
    if end
      css.width = @editor.pixelPositionForScreenPosition(end).left - css.left
    else
      css.right = 0

    region = ($$ -> @div class: 'region').css(css)
    @append(region)
    @regions.push(region)

  getCenterPixelPosition: ->
    { start, end } = @getScreenRange()
    startRow = start.row
    endRow = end.row
    endRow-- if end.column == 0
    @editor.pixelPositionForScreenPosition([((startRow + endRow + 1) / 2), start.column])

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    @selection.getScreenRange()

  getBufferRange: ->
    @selection.getBufferRange()

  needsAutoscroll: ->
    @selection.needsAutoscroll

  clearAutoscroll: ->
    @selection.clearAutoscroll()

  highlight: ->
    @unhighlight()
    @addClass('highlighted')
    clearTimeout(@unhighlightTimeout)
    @unhighlightTimeout = setTimeout((=> @unhighlight()), 1000)

  unhighlight: ->
    @removeClass('highlighted')

  remove: ->
    @editor.removeSelectionView(this)
    super
