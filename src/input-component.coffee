module.exports =
class InputComponent
  constructor: (@domNode) ->

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @oldState ?= {}
    newState = state.hiddenInput

    if newState.top isnt @oldState.top
      @domNode.style.top = newState.top + 'px'
      @oldState.top = newState.top

    if newState.left isnt @oldState.left
      @domNode.style.left = newState.left + 'px'
      @oldState.left = newState.left

    if newState.width isnt @oldState.width
      @domNode.style.width = newState.width + 'px'
      @oldState.width = newState.width

    if newState.height isnt @oldState.height
      @domNode.style.height = newState.height + 'px'
      @oldState.height = newState.height
