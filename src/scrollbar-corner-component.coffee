module.exports =
class ScrollbarCornerComponent
  constructor: ->
    @domNode = document.createElement('div')
    @domNode.classList.add('scrollbar-corner')

    @contentNode = document.createElement('div')
    @domNode.appendChild(@contentNode)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @oldState ?= {}
    @newState ?= {}

    newHorizontalState = state.horizontalScrollbar
    newVerticalState = state.verticalScrollbar
    @newState.visible = newHorizontalState.visible and newVerticalState.visible
    @newState.height = newHorizontalState.height
    @newState.width = newVerticalState.width

    if @newState.visible isnt @oldState.visible
      if @newState.visible
        @domNode.style.display = ''
      else
        @domNode.style.display = 'none'
      @oldState.visible = @newState.visible

    if @newState.height isnt @oldState.height
      @domNode.style.height = @newState.height + 'px'
      @contentNode.style.height = @newState.height + 1 + 'px'
      @oldState.height = @newState.height

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + 'px'
      @contentNode.style.width = @newState.width + 1 + 'px'
      @oldState.width = @newState.width
