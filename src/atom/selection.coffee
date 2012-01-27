Template = require 'template'
Cursor = require 'cursor'
Range = require 'range'
$$ = require 'template/builder'

module.exports =
class Selection extends Template
  content: ->
    @div()

  viewProperties:
    anchor: null
    modifyingSelection: null
    regions: null

    initialize: (@editor) ->
      @regions = []
      @cursor = @editor.cursor
      @cursor.on 'cursor:position-changed', =>
        if @modifyingSelection
          @updateAppearance()
        else
          @clearSelection()

    clearSelection: ->
      @anchor = null
      @updateAppearance()

    bufferChanged: (e) ->
      @cursor.setPosition(e.postRange.end)

    updateAppearance: ->
      @clearRegions()

      range = @getRange()
      return if range.isEmpty()
      for row in [range.start.row..range.end.row]
        start =
          if row == range.start.row
            range.start
          else
            { row: row, column: 0 }

        end =
          if row == range.end.row
            range.end
          else
            null

        @appendRegion(start, end)

    appendRegion: (start, end) ->
      { lineHeight, charWidth } = @editor
      top = start.row * lineHeight
      left = start.column * charWidth
      height = lineHeight
      width = if end
        end.column * charWidth - left
      else
        @editor.width() - left

      region = $$.div(class: 'selection').css({top, left, height, width})
      @append(region)
      @regions.push(region)

    clearRegions: ->
      region.remove() for region in @regions
      @regions = []

    getRange: ->
      if @anchor
        new Range(@anchor.getPosition(), @cursor.getPosition())
      else
        new Range(@cursor.getPosition(), @cursor.getPosition())

    setRange: (range) ->
      @cursor.setPosition(range.start)
      @modifySelection =>
        @cursor.setPosition(range.end)

    insertText: (text) ->
      @editor.buffer.change(@getRange(), text)

    insertNewline: ->
      @insertText('\n')

    backspace: ->
      range = @getRange()

      if range.isEmpty()
        if range.start.column == 0
          return if range.start.row == 0
          range.start.column = @editor.buffer.lines[range.start.row - 1].length
          range.start.row--
        else
          range.start.column--

      @editor.buffer.change(range, '')

    isEmpty: ->
      @getRange().isEmpty()

    modifySelection: (fn) ->
      @placeAnchor()
      @modifyingSelection = true
      fn()
      @modifyingSelection = false

    placeAnchor: ->
      return if @anchor
      cursorPosition = @cursor.getPosition()
      @anchor = { getPosition: -> cursorPosition }

    selectRight: ->
      @modifySelection =>
        @cursor.moveRight()

    selectLeft: ->
      @modifySelection =>
        @cursor.moveLeft()

    selectUp: ->
      @modifySelection =>
        @cursor.moveUp()

    selectDown: ->
      @modifySelection =>
        @cursor.moveDown()

    moveCursorToLineEnd: ->
      @cursor.moveToLineEnd()

    moveCursorToLineStart: ->
      @cursor.moveToLineStart()

