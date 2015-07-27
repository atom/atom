module.exports =
class OverlayManager
  constructor: (@presenter, @container) ->
    @overlaysById = {}

  render: (state) ->
    for decorationId, overlay of state.content.overlays
      if @shouldUpdateOverlay(decorationId, overlay)
        @renderOverlay(state, decorationId, overlay)

    for id, {overlayNode} of @overlaysById
      unless state.content.overlays.hasOwnProperty(id)
        delete @overlaysById[id]
        overlayNode.remove()

  shouldUpdateOverlay: (decorationId, overlay) ->
    cachedOverlay = @overlaysById[decorationId]
    return true unless cachedOverlay?
    cachedOverlay.pixelPosition?.top isnt overlay.pixelPosition?.top or
      cachedOverlay.pixelPosition?.left isnt overlay.pixelPosition?.left

  measureOverlays: ->
    for decorationId, {itemView} of @overlaysById
      @measureOverlay(decorationId, itemView)

  measureOverlay: (decorationId, itemView) ->
    contentMargin = parseInt(getComputedStyle(itemView)['margin-left']) ? 0
    @presenter.setOverlayDimensions(decorationId, itemView.offsetWidth, itemView.offsetHeight, contentMargin)

  renderOverlay: (state, decorationId, {item, pixelPosition, class: klass}) ->
    itemView = atom.views.getView(item)
    cachedOverlay = @overlaysById[decorationId]
    unless overlayNode = cachedOverlay?.overlayNode
      overlayNode = document.createElement('atom-overlay')
      overlayNode.classList.add(klass) if klass?
      @container.appendChild(overlayNode)
      @overlaysById[decorationId] = cachedOverlay = {overlayNode, itemView}

    # The same node may be used in more than one overlay. This steals the node
    # back if it has been displayed in another overlay.
    overlayNode.appendChild(itemView) if overlayNode.childNodes.length is 0

    cachedOverlay.pixelPosition = pixelPosition
    overlayNode.style.top = pixelPosition.top + 'px'
    overlayNode.style.left = pixelPosition.left + 'px'
