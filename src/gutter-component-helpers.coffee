# Helper methods shared among GutterComponent classes.

module.exports =
  # Sets scrollHeight, scrollTop, and backgroundColor on the given domNode.
  setDimensionsAndBackground: (oldState, newState, domNode) ->
    if newState.scrollHeight isnt oldState.scrollHeight
      domNode.style.height = newState.scrollHeight + 'px'
      oldState.scrollHeight = newState.scrollHeight

    if newState.scrollTop isnt oldState.scrollTop
      domNode.style['-webkit-transform'] = "translate3d(0px, #{-newState.scrollTop}px, 0px)"
      oldState.scrollTop = newState.scrollTop

    if newState.backgroundColor isnt oldState.backgroundColor
      domNode.style.backgroundColor = newState.backgroundColor
      oldState.backgroundColor = newState.backgroundColor
