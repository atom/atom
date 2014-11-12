module.exports =
class OverlayManager
  constructor: (@container)->
    @overlays = {}

  render: (props) ->
    {editor, overlayDecorations, lineHeightInPixels} = props

    existingDecorations = null
    for markerId, {isMarkerReversed, startPixelPosition, endPixelPosition, decorations} of overlayDecorations
      for decoration in decorations
        pixelPosition = if isMarkerReversed
          startPixelPosition
        else
          endPixelPosition
        @renderOverlay(editor, decoration, pixelPosition, lineHeightInPixels)

        existingDecorations ?= {}
        existingDecorations[decoration.id] = true

    for id, overlay of @overlays
      unless existingDecorations? and id of existingDecorations
        @container.removeChild(overlay)
        delete @overlays[id]

    return

  renderOverlay: (editor, decoration, pixelPosition, lineHeightInPixels) ->
    item = atom.views.getView(decoration.item)
    unless overlay = @overlays[decoration.id]
      overlay = @overlays[decoration.id] = document.createElement('atom-overlay')
      overlay.appendChild(item)
      @container.appendChild(overlay)

    itemWidth = item.offsetWidth
    itemHeight = item.offsetHeight

    left = pixelPosition.left
    left -= itemWidth if left + itemWidth - editor.getScrollLeft() > editor.getWidth()

    top = pixelPosition.top + lineHeightInPixels
    top -= itemHeight + lineHeightInPixels if top + itemHeight - editor.getScrollTop() > editor.getHeight()

    overlay.style.top = top + 'px'
    overlay.style.left = left + 'px'
