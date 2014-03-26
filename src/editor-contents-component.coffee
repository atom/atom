{React, div, span} = require 'reactionary'
{last} = require 'underscore-plus'

module.exports =
React.createClass
  render: ->
    [startRow, endRow] = @getVisibleRowRange()
    div className: 'lines',
      for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        div className: 'line', @renderScopeTree(tokenizedLine.getScopeTree())

  renderScopeTree: (scopeTree) ->
    if scopeTree.scope?
      span className: ".#{scopeTree.scope}",
        @renderScopeTree(child) for child in scopeTree.children
    else
      scopeTree.value

  getInitialState: ->
    height: 0
    lineHeight: 0
    scrollTop: 0

  getVisibleRowRange: ->
    heightInLines = @state.height / @state.lineHeight
    startRow = Math.floor(@state.scrollTop / @state.lineHeight)
    endRow = startRow + heightInLines
    [startRow, endRow]
