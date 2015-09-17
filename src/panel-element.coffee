{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'
Panel = require './panel'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  initialize: (@model) ->
    @appendChild(@getItemView())

    @classList.add(@model.getClassName().split(' ')...) if @model.getClassName()?
    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))
    this

  getModel: ->
    @model ?= new Panel

  getItemView: ->
    atom.views.getView(@getModel().getItem())

  attachedCallback: ->
    callAttachHooks(@getItemView()) # for backward compatibility with SpacePen views
    @visibleChanged(@getModel().isVisible())
    @positionPopover()

  visibleChanged: (visible) ->
    if visible
      @style.display = null
    else
      @style.display = 'none'

  positionPopover: ->
    unless target = @model.target
      return

    viewport = @model.viewport
    placement = @model.placement.split ' '
    panelRect = @getBoundingClientRect()
    panelRect = # mutable
      top: panelRect.top
      bottom: panelRect.bottom
      left: panelRect.left
      right: panelRect.right
      width: panelRect.width
      height: panelRect.height

    # Target can be a DOM element, a function that returns a rect, or a rect.
    # If they target is dynamic then the popover is continuously positioned in
    # a requestAnimationFrame loop until it's hidden.
    if targetRect = target.getBoundingClientRect?()
      schedulePositionPopovers()
    else if targetRect ?= target?()
      schedulePositionPopovers()
    else
      targetRect = target

    # Target can be a DOM element, a function that returns a rect, or a rect.
    # If they viewport is dynamic then the popover is continuously positioned
    # in a requestAnimationFrame loop until it's hidden.
    if viewportRect = viewport?.getBoundingClientRect?()
      schedulePositionPopovers()
    else if viewportRect ?= viewport?()
      schedulePositionPopovers()
    else
      viewportRect = viewport

    placePrimary = placement[0]
    placeSecondary = placement[1]
    constraintedPlacePrimary = placePrimary

    # Initial positioning and report when out of viewport
    out = @positionPopoverRect panelRect, targetRect, placePrimary, placeSecondary, viewportRect

    # Flip placement and reposition panel rect if out of viewport
    if out.top and constraintedPlacePrimary is 'top'
      constraintedPlacePrimary = 'bottom'
    else if out.bottom and constraintedPlacePrimary is 'bottom'
      constraintedPlacePrimary = 'top'
    else if out.left and constraintedPlacePrimary is 'left'
      constraintedPlacePrimary = 'right'
    else if out.right and constraintedPlacePrimary is 'right'
      constraintedPlacePrimary = 'left'

    unless placePrimary is constraintedPlacePrimary
      out = @positionPopoverRect panelRect, targetRect, constraintedPlacePrimary, placeSecondary, viewportRect

    # Constrain panel rect to viewport
    if out.top
      panelRect.top = viewportRect.top
    else if out.bottom
      panelRect.top = viewportRect.bottom - panelRect.height
    else if out.left
      panelRect.left = viewportRect.left
    else if out.right
      panelRect.left = viewportRect.right - panelRect.width

    # Update panel top, left style if changed
    unless @cachedTop is panelRect.top and @cachedLeft is panelRect.left
      unless @_arrowDIV
        @_arrowDIV = document.createElement 'div'
        @_arrowDIV.classList.add 'arrow'
        @insertBefore @_arrowDIV, @firstChild

      @setAttribute 'data-arrow', constraintedPlacePrimary
      @style.top = panelRect.top + 'px'
      @style.left = panelRect.left + 'px'
      @cachedTop = panelRect.top
      @cachedLeft = panelRect.left

  positionPopoverRect: (panelRect, targetRect, placePrimary, placeSecondary, viewportRect) ->
    switch placePrimary
      when 'top'
        panelRect.top = targetRect.top - panelRect.height
      when 'bottom'
        panelRect.top = targetRect.bottom
      when 'left'
        panelRect.left = targetRect.left - panelRect.width
      when 'right'
        panelRect.left = targetRect.right

    switch placeSecondary
      when 'left'
        panelRect.left = targetRect.left
      when 'center'
        panelRect.left = targetRect.left - ((panelRect.width - targetRect.width) / 2.0)
      when 'right'
        panelRect.left = targetRect.right - panelRect.width
      when 'top'
        panelRect.top = targetRect.top
      when 'middle'
        panelRect.top = targetRect.top - ((panelRect.height - targetRect.height) / 2.0)
      when 'bottom'
        panelRect.top = targetRect.bottom - panelRect.height

    panelRect.bottom = panelRect.top + panelRect.height
    panelRect.right = panelRect.left + panelRect.width
    out = {}

    if viewportRect
      if panelRect.top < viewportRect.top
        out['top'] = true
      if panelRect.bottom > viewportRect.bottom
        out['bottom'] = true
      if panelRect.left < viewportRect.left
        out['left'] = true
      if panelRect.right > viewportRect.right
        out['right'] = true

    out

  destroyed: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)


# Popover positioning is performed in a `requestAnimationFrame` loop when
# either of `target` or `viewport` are dynamic (ie functions or elements)
positionPopoversFrameID = null
schedulePositionPopovers = ->
  unless positionPopoversFrameID
    positionPopoversFrameID = window.requestAnimationFrame positionPopovers

positionPopovers = ->
  positionPopoversFrameID = null
  for panel in atom.workspace.getPopoverPanels()
    if panel.isVisible()
      atom.views.getView(panel).positionPopover()

module.exports = PanelElement = document.registerElement 'atom-panel', prototype: PanelElement.prototype
