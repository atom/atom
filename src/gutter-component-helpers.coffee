# Helper methods shared among GutterComponent classes.

module.exports =
  createGutterView: (gutterModel) ->
    domNode = document.createElement('div')
    domNode.classList.add('gutter')
    domNode.setAttribute('gutter-name', gutterModel.name)
    childNode = document.createElement('div')
    if gutterModel.name is 'line-number'
      childNode.classList.add('line-numbers')
    else
      childNode.classList.add('custom-decorations')
    domNode.appendChild(childNode)
    domNode

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
