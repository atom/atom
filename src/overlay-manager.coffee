module.exports =
class OverlayManager
  constructor: (@container) ->
    @overlays = {}

  render: (props) ->
    {presenter, editor, overlayDecorations} = props
    lineHeight = presenter.getLineHeight()

    existingDecorations = null
    for markerId, {headPixelPosition, tailPixelPosition, decorations} of overlayDecorations
      for decoration in decorations
        pixelPosition =
          if decoration.position is 'tail' then tailPixelPosition else headPixelPosition

        @renderOverlay(editor, decoration, pixelPosition, lineHeight)

        existingDecorations ?= {}
        existingDecorations[decoration.id] = true

    for id, overlay of @overlays
      unless existingDecorations? and id of existingDecorations
        @container.removeChild(overlay)
        delete @overlays[id]

    return

  renderOverlay: (editor, decoration, pixelPosition, lineHeight) ->
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

    top = pixelPosition.top + lineHeight
    if top + itemHeight - editor.getScrollTop() > editor.getHeight() and top - itemHeight - lineHeight >= editor.getScrollTop()
      top -= itemHeight + lineHeight

    overlay.style.top = top + 'px'
    overlay.style.left = left + 'px'
