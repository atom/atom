{React, div, span} = require 'reactionary'
{last} = require 'underscore-plus'

module.exports =
React.createClass
  render: ->
    div class: 'lines', @renderVisibleLines()

  renderVisibleLines: ->
    return [] unless @props.lineHeight > 0

    [startRow, endRow] = @getVisibleRowRange()
    for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
      LineComponent({tokenizedLine, key: tokenizedLine.id})

  getDefaultProps: ->
    height: 0
    lineHeight: 0
    scrollTop: 0

  getVisibleRowRange: ->
    heightInLines = @props.height / @props.lineHeight
    startRow = Math.floor(@props.scrollTop / @props.lineHeight)
    endRow = Math.ceil(startRow + heightInLines)
    [startRow, endRow]

  onScreenLinesChanged: ({start, end}) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    @forceUpdate() unless end < visibleStart or visibleEnd <= start

LineComponent = React.createClass
  render: ->
    {tokenizedLine} = @props
    div class: 'line',
      if tokenizedLine.text.length is 0
        span {}, String.fromCharCode(160) # non-breaking space; bypasses escaping
      else
        @renderScopeTree(tokenizedLine.getScopeTree())

  renderScopeTree: (scopeTree) ->
    if scopeTree.scope?
      span class: scopeTree.scope.split('.').join(' '),
        scopeTree.children.map (child) => @renderScopeTree(child)
    else
      span scopeTree.value
