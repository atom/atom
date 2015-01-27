module.exports =
class OverlayManager
  constructor: (@container) ->
    @overlayNodesById = {}

  render: (props) ->
    {presenter} = props

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


    {scrollTop} = presenter.state
    {scrollLeft} = presenter.state.content

    left = pixelPosition.left
    if left + itemWidth - scrollLeft > presenter.getClientWidth() and left - itemWidth >= scrollLeft
      left -= itemWidth

    top = pixelPosition.top + presenter.getLineHeight()
    if top + itemHeight - scrollTop > presenter.getClientHeight() and top - itemHeight - presenter.getLineHeight() >= scrollTop
      top -= itemHeight + presenter.getLineHeight()

    overlayNode.style.top = top + 'px'
    overlayNode.style.left = left + 'px'
