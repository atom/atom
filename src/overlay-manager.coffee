module.exports =
class OverlayManager
  constructor: (@presenter, @container) ->
    @overlayNodesById = {}

  render: (state) ->
    for decorationId, {pixelPosition, item} of state.content.overlays
      @renderOverlay(state, decorationId, item, pixelPosition)

    for id, overlayNode of @overlayNodesById
      unless state.content.overlays.hasOwnProperty(id)
        delete @overlayNodesById[id]
        overlayNode.remove()

    return

  renderOverlay: (state, decorationId, item, pixelPosition) ->
    item = atom.views.getView(item)
    unless overlayNode = @overlayNodesById[decorationId]
      overlayNode = @overlayNodesById[decorationId] = document.createElement('atom-overlay')
      overlayNode.appendChild(item)
      @container.appendChild(overlayNode)

    itemWidth = item.offsetWidth
    itemHeight = item.offsetHeight
    contentMargin = parseInt(getComputedStyle(item)['margin-left']) ? 0

    {scrollTop, scrollLeft} = state.content

    editorBounds = @presenter.boundingClientRect
    gutterWidth = editorBounds.width - @presenter.contentFrameWidth

    left = pixelPosition.left - scrollLeft + gutterWidth
    top = pixelPosition.top + @presenter.lineHeight - scrollTop

    rightDiff = left + editorBounds.left + itemWidth + contentMargin - @presenter.windowWidth
    left -= rightDiff if rightDiff > 0

    leftDiff = left + editorBounds.left + contentMargin
    left -= leftDiff if leftDiff < 0

    if top + editorBounds.top + itemHeight > @presenter.windowHeight
      top -= itemHeight + @presenter.lineHeight

    overlayNode.style.top = top + 'px'
    overlayNode.style.left = left + 'px'
