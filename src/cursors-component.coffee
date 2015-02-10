module.exports =
class CursorsComponent
  oldState: null

  constructor: (@presenter) ->
    @cursorNodesById = {}
    @domNode = document.createElement('div')
    @domNode.classList.add('cursors')
    @updateSync()

  updateSync: ->
    newState = @presenter.state.content
    @oldState ?= {cursors: {}}

    # update blink class
    if newState.blinkCursorsOff isnt @oldState.blinkCursorsOff
      if newState.blinkCursorsOff
        @domNode.classList.add 'blink-off'
      else
        @domNode.classList.remove 'blink-off'
      @oldState.blinkCursorsOff = newState.blinkCursorsOff

    # remove cursors
    for id of @oldState.cursors
      unless newState.cursors[id]?
        @cursorNodesById[id].remove()
        delete @cursorNodesById[id]
        delete @oldState.cursors[id]

    # add or update cursors
    for id, cursorState of newState.cursors
      unless @oldState.cursors[id]?
        cursorNode = document.createElement('div')
        cursorNode.classList.add('cursor')
        @cursorNodesById[id] = cursorNode
        @domNode.appendChild(cursorNode)
      @updateCursorNode(id, cursorState)

  updateCursorNode: (id, newCursorState) ->
    cursorNode = @cursorNodesById[id]
    oldCursorState = (@oldState.cursors[id] ?= {})

    if newCursorState.top isnt oldCursorState.top or newCursorState.left isnt oldCursorState.left
      cursorNode.style['-webkit-transform'] = "translate(#{newCursorState.left}px, #{newCursorState.top}px)"
      oldCursorState.top = newCursorState.top
      oldCursorState.left = newCursorState.left

    if newCursorState.height isnt oldCursorState.height
      cursorNode.style.height = newCursorState.height + 'px'
      oldCursorState.height = newCursorState.height

    if newCursorState.width isnt oldCursorState.width
      cursorNode.style.width = newCursorState.width + 'px'
      oldCursorState.width = newCursorState.width
