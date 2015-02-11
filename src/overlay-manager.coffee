module.exports =
class OverlayManager
  constructor: (@container) ->
    @overlayNodesById = {}

  render: (presenter) ->
    for decorationId, {pixelPosition, item} of presenter.state.content.overlays
      @renderOverlay(presenter, decorationId, item, pixelPosition)

    for id, overlayNode of @overlayNodesById
      unless presenter.state.content.overlays.hasOwnProperty(id)
        overlayNode.remove()
        delete @overlayNodesById[id]

    return

  renderOverlay: (presenter, decorationId, item, pixelPosition) ->
    item = atom.views.getView(item)
    unless overlayNode = @overlayNodesById[decorationId]
      overlayNode = @overlayNodesById[decorationId] = document.createElement('atom-overlay')
      overlayNode.appendChild(item)
      @container.appendChild(overlayNode)

    itemWidth = item.offsetWidth
    itemHeight = item.offsetHeight


    {scrollTop, scrollLeft} = presenter.state.content

    left = pixelPosition.left
    if left + itemWidth - scrollLeft > presenter.contentFrameWidth and left - itemWidth >= scrollLeft
      left -= itemWidth

    top = pixelPosition.top + presenter.lineHeight
    if top + itemHeight - scrollTop > presenter.height and top - itemHeight - presenter.lineHeight >= scrollTop
      top -= itemHeight + presenter.lineHeight

    overlayNode.style.top = top + 'px'
    overlayNode.style.left = left + 'px'
