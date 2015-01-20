module.exports =
class OverlayManager
  constructor: (@container) ->
    @overlays = {}

  render: (props) ->
    {editor, overlayDecorations, lineHeightInPixels} = props

    existingDecorations = null
    for markerId, {isMarkerReversed, headPixelPosition, decorations} of overlayDecorations
      for decoration in decorations
        @renderOverlay(editor, decoration, headPixelPosition, lineHeightInPixels)

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
    if left + itemWidth - editor.getScrollLeft() > editor.getWidth() and left - itemWidth >= editor.getScrollLeft()
      left -= itemWidth

    top = pixelPosition.top + lineHeightInPixels
    if top + itemHeight - editor.getScrollTop() > editor.getHeight() and top - itemHeight - lineHeightInPixels >= editor.getScrollTop()
      top -= itemHeight + lineHeightInPixels

    overlay.style.top = top + 'px'
    overlay.style.left = left + 'px'
