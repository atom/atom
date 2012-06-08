Range = require 'range'
Anchor = require 'new-anchor'
EventEmitter = require 'event-emitter'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
_ = require 'underscore'

module.exports =
class Selection
  anchor: null

  constructor: ({@cursor, @editSession}) ->
    @cursor.on 'change-screen-position.selection', (e) =>
      @trigger 'change-screen-range', @getScreenRange() unless e.bufferChanged

    @cursor.on 'destroy.selection', =>
      @cursor = null
      @destroy()

  destroy: ->
    if @cursor
      @cursor.off('.selection')
      @cursor.destroy()
    @editSession.removeSelection(this)
    @trigger 'destroy'

  getScreenRange: ->
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (screenRange, options={})->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    [start, end] = [end, start] if options.reverse

    @modifyScreenRange =>
      @placeAnchor() unless @anchor
      @modifySelection =>
        @anchor.setScreenPosition(start)
        @cursor.setScreenPosition(end)

  getBufferRange: ->
    if @anchor
      new Range(@anchor.getBufferPosition(), @cursor.getBufferPosition())
    else
      new Range(@cursor.getBufferPosition(), @cursor.getBufferPosition())

  clear: ->
    @modifyScreenRange => @anchor = null

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clear()
    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
    @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed
    @autoOutdentText() if shouldOutdent

  autoIndentText: (text) ->
    if @editSession.autoIndentEnabled()
      mode = @editSession.getCurrentMode()
      row = @cursor.getCurrentScreenRow()
      state = @editSession.stateForScreenRow(row)
      lineBeforeCursor = @cursor.getCurrentBufferLine()[0...@cursor.getBufferPosition().column]
      if text[0] == "\n"
        indent = mode.getNextLineIndent(state, lineBeforeCursor, @editSession.tabText)
        text = text[0] + indent + text[1..]
      else if mode.checkOutdent(state, lineBeforeCursor, text)
        shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentText: ->
    screenRow = @cursor.getCurrentScreenRow()
    bufferRow = @cursor.getCurrentBufferRow()
    state = @editSession.stateForScreenRow(screenRow)
    @editSession.getCurrentMode().autoOutdent(state, new AceOutdentAdaptor(@editSession), bufferRow)

  handleBufferChange: (e) ->
    @modifyScreenRange =>
      @anchor?.handleBufferChange(e)
      @cursor.handleBufferChange(e)

  modifySelection: (fn) ->
    @retainSelection = true
    @view?.retainSelection = true
    @placeAnchor() unless @anchor
    fn()
    @retainSelection = false
    @view?.retainSelection = false

  modifyScreenRange: (fn) ->
    oldScreenRange = @getScreenRange()
    fn()
    newScreenRange = @getScreenRange()
    @trigger 'change-screen-range', newScreenRange unless oldScreenRange.isEqual(newScreenRange)

  placeAnchor: ->
    @anchor = new Anchor(@editSession)
    @anchor.setScreenPosition(@cursor.getScreenPosition())

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  merge: (otherSelection, options) ->
    @setScreenRange(@getScreenRange().union(otherSelection.getScreenRange()), options)
    otherSelection.destroy()

_.extend Selection.prototype, EventEmitter
