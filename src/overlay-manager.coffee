module.exports =
class OverlayManager
  constructor: (@presenter, @container) ->
    @overlaysById = {}

  render: (state) ->
    editorDimensionsHaveChanged = !@editorDimensionsAreEqual(state)

    for decorationId, overlay of state.content.overlays
      overlayHasChanged = not @overlayStateIsEqual(decorationId, overlay)
      if editorDimensionsHaveChanged or overlayHasChanged
        @renderOverlay(state, decorationId, overlay)
        @cacheOverlayState(decorationId, overlay)

    for id, {overlayNode} of @overlaysById
      unless state.content.overlays.hasOwnProperty(id)
        delete @overlaysById[id]
        overlayNode.remove()

    @cacheEditorDimensions(state)

  overlayStateIsEqual: (decorationId, overlay) ->
    return false unless @overlaysById[decorationId]?
    @overlaysById[decorationId].itemWidth is overlay.itemWidth and
      @overlaysById[decorationId].itemHeight is overlay.itemHeight and
      @overlaysById[decorationId].contentMargin is overlay.contentMargin and
      @overlaysById[decorationId].pixelPosition?.top is overlay.pixelPosition?.top and
      @overlaysById[decorationId].pixelPosition?.left is overlay.pixelPosition?.left

  cacheOverlayState: (decorationId, overlay) ->
    return unless @overlaysById[decorationId]?
    @overlaysById[decorationId].itemWidth = overlay.itemWidth
    @overlaysById[decorationId].itemHeight = overlay.itemHeight
    @overlaysById[decorationId].contentMargin = overlay.contentMargin
    @overlaysById[decorationId].pixelPosition = overlay.pixelPosition

  cacheEditorDimensions: (state) ->
    @cachedEditorDimensions =
      lineHeight: @presenter.lineHeight
      contentFrameWidth: @presenter.contentFrameWidth
      editorTop: @presenter.boundingClientRect?.top
      editorLeft: @presenter.boundingClientRect?.left
      editorWidth: @presenter.boundingClientRect?.width
      windowWidth: @presenter.windowWidth
      windowHeight: @presenter.windowHeight
      scrollTop: state.content.scrollTop
      scrollLeft: state.content.scrollLeft

  editorDimensionsAreEqual: (state) ->
    return false unless @cachedEditorDimensions?
    @cachedEditorDimensions.lineHeight is @presenter.lineHeight and
      @cachedEditorDimensions.contentFrameWidth is @presenter.contentFrameWidth and
      @cachedEditorDimensions.editorTop is @presenter.boundingClientRect?.top and
      @cachedEditorDimensions.editorLeft is @presenter.boundingClientRect?.left and
      @cachedEditorDimensions.editorWidth is @presenter.boundingClientRect?.width and
      @cachedEditorDimensions.windowWidth is @presenter.windowWidth and
      @cachedEditorDimensions.windowHeight is @presenter.windowHeight and
      @cachedEditorDimensions.scrollTop is state.content.scrollTop and
      @cachedEditorDimensions.scrollLeft is state.content.scrollLeft

  measureOverlays: ->
    for decorationId, {item} of @overlaysById
      @measureOverlay(decorationId, item)

  measureOverlay: (decorationId, item) ->
    contentMargin = parseInt(getComputedStyle(item)['margin-left']) ? 0
    @presenter.setOverlayDimensions(decorationId, item.offsetWidth, item.offsetHeight, contentMargin)

  renderOverlay: (state, decorationId, {item, pixelPosition}) ->
    item = atom.views.getView(item)
    overlay = @overlaysById[decorationId]
    unless overlayNode = overlay?.overlayNode
      overlayNode = document.createElement('atom-overlay')
      overlayNode.appendChild(item)
      @container.appendChild(overlayNode)
      @overlaysById[decorationId] = overlay = {overlayNode, item}

    overlayDimensions = @presenter.getOverlayDimensions(decorationId)
    unless overlayDimensions?.itemWidth?
      @measureOverlay(decorationId, item)
      overlayDimensions = @presenter.getOverlayDimensions(decorationId)

    {itemWidth, itemHeight, contentMargin} = overlayDimensions
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
