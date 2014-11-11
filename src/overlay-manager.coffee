module.exports =
class OverlayManager
  constructor: ->
    @overlays = {}

  render: (props) ->
    {hostElement, editor, overlayDecorations, lineHeightInPixels} = props

    existingDecorations = null
    for markerId, {startPixelPosition, endPixelPosition, decorations} of overlayDecorations
      for decoration in decorations
        @renderOverlay(hostElement, decoration, endPixelPosition)

        existingDecorations ?= {}
        existingDecorations[decoration.id] = true

    for id, overlay of @overlays
      unless existingDecorations? and id of existingDecorations
        hostElement.removeChild(overlay)
        delete @overlays[id]

    return

  renderOverlay: (hostElement, decoration, endPixelPosition) ->
    unless overlay = @overlays[decoration.id]
      overlay = @overlays[decoration.id] = document.createElement('atom-overlay')
      overlay.appendChild(atom.views.getView(decoration.item))
      hostElement.appendChild(overlay)

    overlay.style.top = endPixelPosition.top + 'px'
    overlay.style.left = endPixelPosition.left + 'px'
