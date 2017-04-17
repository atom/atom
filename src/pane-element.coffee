path = require 'path'
{CompositeDisposable} = require 'event-kit'

class PaneElement extends HTMLElement
  attached: false

  createdCallback: ->
    @attached = false
    @subscriptions = new CompositeDisposable
    @inlineDisplayStyles = new WeakMap

    @initializeContent()
    @subscribeToDOMEvents()

  attachedCallback: ->
    @attached = true
    @focus() if @model.isFocused()

  detachedCallback: ->
    @attached = false

  initializeContent: ->
    @setAttribute 'class', 'pane'
    @setAttribute 'tabindex', -1
    @appendChild @itemViews = document.createElement('div')
    @itemViews.setAttribute 'class', 'item-views'

  subscribeToDOMEvents: ->
    handleFocus = (event) =>
      @model.focus() unless @isActivating or @model.isDestroyed() or @contains(event.relatedTarget)
      if event.target is this and view = @getActiveView()
        view.focus()
        event.stopPropagation()

    handleBlur = (event) =>
      @model.blur() unless @contains(event.relatedTarget)

    handleDragOver = (event) ->
      event.preventDefault()
      event.stopPropagation()

    handleDrop = (event) =>
      event.preventDefault()
      event.stopPropagation()
      @getModel().activate()
      pathsToOpen = Array::map.call event.dataTransfer.files, (file) -> file.path
      @applicationDelegate.open({pathsToOpen}) if pathsToOpen.length > 0

    @addEventListener 'focus', handleFocus, true
    @addEventListener 'blur', handleBlur, true
    @addEventListener 'dragover', handleDragOver
    @addEventListener 'drop', handleDrop

  initialize: (@model, {@views, @applicationDelegate}) ->
    throw new Error("Must pass a views parameter when initializing PaneElements") unless @views?
    throw new Error("Must pass an applicationDelegate parameter when initializing PaneElements") unless @applicationDelegate?

    @subscriptions.add @model.onDidActivate(@activated.bind(this))
    @subscriptions.add @model.observeActive(@activeStatusChanged.bind(this))
    @subscriptions.add @model.observeActiveItem(@activeItemChanged.bind(this))
    @subscriptions.add @model.onDidRemoveItem(@itemRemoved.bind(this))
    @subscriptions.add @model.onDidDestroy(@paneDestroyed.bind(this))
    @subscriptions.add @model.observeFlexScale(@flexScaleChanged.bind(this))
    this

  getModel: -> @model

  activated: ->
    @isActivating = true
    @focus()
    @isActivating = false

  activeStatusChanged: (active) ->
    if active
      @classList.add('active')
    else
      @classList.remove('active')

  activeItemChanged: (item) ->
    delete @dataset.activeItemName
    delete @dataset.activeItemPath

    return unless item?

    hasFocus = @hasFocus()
    itemView = @views.getView(item)

    if itemPath = item.getPath?()
      @dataset.activeItemName = path.basename(itemPath)
      @dataset.activeItemPath = itemPath

    unless @itemViews.contains(itemView)
      @itemViews.appendChild(itemView)

    for child in @itemViews.children
      if child is itemView
        @showItemView(child) if @attached
      else
        @hideItemView(child)

    itemView.focus() if hasFocus

  showItemView: (itemView) ->
    inlineDisplayStyle = @inlineDisplayStyles.get(itemView)
    if inlineDisplayStyle?
      itemView.style.display = inlineDisplayStyle
    else
      itemView.style.display = ''

  hideItemView: (itemView) ->
    inlineDisplayStyle = itemView.style.display
    unless inlineDisplayStyle is 'none'
      @inlineDisplayStyles.set(itemView, inlineDisplayStyle) if inlineDisplayStyle?
      itemView.style.display = 'none'

  itemRemoved: ({item, index, destroyed}) ->
    if viewToRemove = @views.getView(item)
      viewToRemove.remove()

  paneDestroyed: ->
    @subscriptions.dispose()

  flexScaleChanged: (flexScale) ->
    @style.flexGrow = flexScale

  getActiveView: -> @views.getView(@model.getActiveItem())

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

module.exports = PaneElement = document.registerElement 'atom-pane', prototype: PaneElement.prototype
