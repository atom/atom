{View, $$, $$$} = require './space-pen-extensions'
{Range} = require 'telepath'
$ = require './jquery-extensions'
_ = require 'underscore-plus'

# Private: Represents the portion of the {Editor} containing row numbers.
#
# The gutter also indicates if rows are folded.
module.exports =
class Gutter extends View

  ### Internal ###

  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'line-numbers'

  firstScreenRow: null
  lastScreenRow: null

  initialize: ->
    @elementBuilder = document.createElement('div')

  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true

    highlightLines = => @highlightLines()
    @getEditor().on 'cursor:moved', highlightLines
    @getEditor().on 'selection:changed', highlightLines
    @on 'mousedown', (e) => @handleMouseEvents(e)

  beforeRemove: ->
    $(document).off(".gutter-#{@getEditor().id}")

  handleMouseEvents: (e) ->
    editor = @getEditor()
    startRow = editor.screenPositionFromMouseEvent(e).row
    if e.shiftKey
      editor.selectToScreenPosition([startRow + 1, 0])
      return
    else
      editor.getSelection().setScreenRange([[startRow, 0], [startRow, 0]])

    moveHandler = (e) =>
      start = startRow
      end = editor.screenPositionFromMouseEvent(e).row
      if end > start then end++ else start++
      editor.getSelection().setScreenRange([[start, 0], [end, 0]])

    $(document).on "mousemove.gutter-#{@getEditor().id}", moveHandler
    $(document).one "mouseup.gutter-#{@getEditor().id}", => $(document).off 'mousemove', moveHandler

  ### Public ###

  # Retrieves the containing {Editor}.
  #
  # Returns an {Editor}.
  getEditor: ->
    @parentView

  # Defines whether to show the gutter or not.
  #
  # showLineNumbers - A {Boolean} which, if `false`, hides the gutter
  setShowLineNumbers: (showLineNumbers) ->
    if showLineNumbers then @lineNumbers.show() else @lineNumbers.hide()

  # Get all the line-number divs.
  #
  # Returns a list of {HTMLElement}s.
  getLineNumberElements: ->
    @lineNumbers[0].children

  # Get all the line-number divs.
  #
  # Returns a list of {HTMLElement}s.
  getLineNumberElementsForClass: (klass) ->
    @lineNumbers[0].getElementsByClassName(klass)

  # Get a single line-number div.
  #
  # * bufferRow: 0 based line number
  #
  # Returns a list of {HTMLElement}s that correspond to the bufferRow. More than
  # one in the list indicates a wrapped line.
  getLineNumberElement: (bufferRow) ->
    @getLineNumberElementsForClass("line-number-#{bufferRow}")

  # Add a class to all line-number divs.
  #
  # * klass: string class name
  #
  # Returns true if the class was added to any lines
  addClassToAllLines: (klass)->
    elements = @getLineNumberElements()
    el.classList.add(klass) for el in elements
    !!elements.length

  # Remove a class from all line-number divs.
  #
  # * klass: string class name. Can only be one class name. i.e. 'my-class'
  #
  # Returns true if the class was removed from any lines
  removeClassFromAllLines: (klass)->
    # This is faster than calling $.removeClass on all lines, and faster than
    # making a new array and iterating through it.
    elements = @getLineNumberElementsForClass(klass)
    willRemoveClasses = !!elements.length
    elements[0].classList.remove(klass) while elements.length > 0
    willRemoveClasses

  # Add a class to a single line-number div
  #
  # * bufferRow: 0 based line number
  # * klass: string class name
  #
  # Returns true if there were lines the class was added to
  addClassToLine: (bufferRow, klass)->
    elements = @getLineNumberElement(bufferRow)
    el.classList.add(klass) for el in elements
    !!elements.length

  # Remove a class from a single line-number div
  #
  # * bufferRow: 0 based line number
  # * klass: string class name
  #
  # Returns true if there were lines the class was removed from
  removeClassFromLine: (bufferRow, klass)->
    classesRemoved = false
    elements = @getLineNumberElement(bufferRow)
    for el in elements
      hasClass = el.classList.contains(klass)
      classesRemoved |= hasClass
      el.classList.remove(klass) if hasClass
    classesRemoved

  ### Internal ###

  updateLineNumbers: (changes, startScreenRow, endScreenRow) ->
    # Check if we have something already rendered that overlaps the requested range
    updateAllLines = not (startScreenRow? and endScreenRow?)
    updateAllLines |= endScreenRow <= @firstScreenRow or startScreenRow >= @lastScreenRow

    for change in changes
      # When there is a change to the bufferRow -> screenRow map (i.e. a fold),
      # then rerender everything.
      if (change.screenDelta or change.bufferDelta) and change.screenDelta != change.bufferDelta
        updateAllLines = true
        break

    if updateAllLines
      @lineNumbers[0].innerHTML = @buildLineElementsHtml(startScreenRow, endScreenRow)
    else
      # When scrolling or adding/removing lines, we just add/remove lines from the ends.
      if startScreenRow < @firstScreenRow
        @prependLineElements(@buildLineElements(startScreenRow, @firstScreenRow-1))
      else if startScreenRow != @firstScreenRow
        @removeLineElements(startScreenRow - @firstScreenRow)

      if endScreenRow > @lastScreenRow
        @appendLineElements(@buildLineElements(@lastScreenRow+1, endScreenRow))
      else if endScreenRow != @lastScreenRow
        @removeLineElements(endScreenRow - @lastScreenRow)

    @firstScreenRow = startScreenRow
    @lastScreenRow = endScreenRow
    @highlightedRows = null
    @highlightLines()

  prependLineElements: (lineElements) ->
    anchor = @lineNumbers[0].children[0]
    return appendLineElements(lineElements) unless anchor?
    @lineNumbers[0].insertBefore(lineElements[0], anchor) while lineElements.length > 0
    null # defeat coffeescript array return

  appendLineElements: (lineElements) ->
    @lineNumbers[0].appendChild(lineElements[0]) while lineElements.length > 0
    null # defeat coffeescript array return

  removeLineElements: (numberOfElements) ->
    children = @getLineNumberElements()

    # children is a live NodeList, so remove from the desired end {numberOfElements} times
    if numberOfElements < 0
      @lineNumbers[0].removeChild(children[children.length-1]) while numberOfElements++
    else if numberOfElements > 0
      @lineNumbers[0].removeChild(children[0]) while numberOfElements--

    null # defeat coffeescript array return

  buildLineElements: (startScreenRow, endScreenRow) ->
    @elementBuilder.innerHTML = @buildLineElementsHtml(startScreenRow, endScreenRow)
    @elementBuilder.children

  buildLineElementsHtml: (startScreenRow, endScreenRow) =>
    editor = @getEditor()
    maxDigits = editor.getLineCount().toString().length
    rows = editor.bufferRowsForScreenRows(startScreenRow, endScreenRow)

    html = ''
    for row in rows
      if row == lastScreenRow
        rowValue = '•'
      else
        rowValue = (row + 1).toString()

      classes = "line-number line-number-#{row}"
      classes += ' fold' if editor.isFoldedAtBufferRow(row)

      rowValuePadding = _.multiplyString('&nbsp;', maxDigits - rowValue.length)

      html += """<div class="#{classes}">#{rowValuePadding}#{rowValue}</div>"""

      lastScreenRow = row

    html

  removeLineHighlights: ->
    return unless @highlightedLineNumbers
    for line in @highlightedLineNumbers
      line.classList.remove('cursor-line')
      line.classList.remove('cursor-line-no-selection')
    @highlightedLineNumbers = null

  addLineHighlight: (row, emptySelection) ->
    return if row < @firstScreenRow or row > @lastScreenRow
    @highlightedLineNumbers ?= []
    if highlightedLineNumber = @lineNumbers[0].children[row - @firstScreenRow]
      highlightedLineNumber.classList.add('cursor-line')
      highlightedLineNumber.classList.add('cursor-line-no-selection') if emptySelection
      @highlightedLineNumbers.push(highlightedLineNumber)

  highlightLines: ->
    if @getEditor().getSelection().isEmpty()
      row = @getEditor().getCursorScreenPosition().row
      rowRange = new Range([row, 0], [row, 0])
      return if @selectionEmpty and @highlightedRows?.isEqual(rowRange)

      @removeLineHighlights()
      @addLineHighlight(row, true)
      @highlightedRows = rowRange
      @selectionEmpty = true
    else
      selectedRows = @getEditor().getSelection().getScreenRange()
      endRow = selectedRows.end.row
      endRow-- if selectedRows.end.column is 0
      selectedRows = new Range([selectedRows.start.row, 0], [endRow, 0])
      return if not @selectionEmpty and @highlightedRows?.isEqual(selectedRows)

      @removeLineHighlights()
      for row in [selectedRows.start.row..selectedRows.end.row]
        @addLineHighlight(row, false)
      @highlightedRows = selectedRows
      @selectionEmpty = false
