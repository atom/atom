Anchor = require 'anchor'
Point = require 'point'
Range = require 'range'
{View, $$} = require 'space-pen'

module.exports =
class SelectionView extends View
  @content: ->
    @div()

  regions: null
  destroyed: false

  initialize: ({@editor, @selection} = {}) ->
    @regions = []
    @selection.on 'change-screen-range', => @editor.requestDisplayUpdate()
    @selection.on 'destroy', =>
      @destroyed = true
      @editor.requestDisplayUpdate()

  updateDisplay: ->
    @clearRegions()
    range = @getScreenRange()

    @trigger 'selection-change'
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

    region = ($$ -> @div class: 'selection').css(css)
    @append(region)
    @regions.push(region)

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    @selection.getScreenRange()

  getBufferRange: ->
    @selection.getBufferRange()

  remove: ->
    @editor.removeSelectionView(this)
    super
