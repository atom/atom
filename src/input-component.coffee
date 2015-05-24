module.exports =
class InputComponent
  constructor: ->
    @domNode = document.createElement('input')
    @domNode.classList.add('hidden-input')
    @domNode.setAttribute('data-react-skip-selection-restoration', true)
    @domNode.style['-webkit-transform'] = 'translateZ(0)'
    @domNode.addEventListener 'paste', (event) -> event.preventDefault()

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
