path = require 'path'
{CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
{$, callAttachHooks, callRemoveHooks} = require './space-pen-extensions'
PaneView = null

class PaneElement extends HTMLElement
  attached: false

  createdCallback: ->
    @attached = false
    @subscriptions = new CompositeDisposable
    @inlineDisplayStyles = new WeakMap

    @initializeContent()
    @subscribeToDOMEvents()
    @createSpacePenShim() if Grim.includeDeprecatedAPIs

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
      @model.focus()
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
      atom.open({pathsToOpen}) if pathsToOpen.length > 0

    @addEventListener 'focus', handleFocus, true
    @addEventListener 'blur', handleBlur, true
    @addEventListener 'dragover', handleDragOver
    @addEventListener 'drop', handleDrop

  createSpacePenShim: ->
    PaneView ?= require './pane-view'
    @__spacePenView = new PaneView(this)

  initialize: (@model) ->
    @subscriptions.add @model.onDidActivate(@activated.bind(this))
    @subscriptions.add @model.observeActive(@activeStatusChanged.bind(this))
    @subscriptions.add @model.observeActiveItem(@activeItemChanged.bind(this))
    @subscriptions.add @model.onDidRemoveItem(@itemRemoved.bind(this))
    @subscriptions.add @model.onDidDestroy(@paneDestroyed.bind(this))
    @subscriptions.add @model.observeFlexScale(@flexScaleChanged.bind(this))

    @__spacePenView.setModel(@model) if Grim.includeDeprecatedAPIs
    this

  getModel: -> @model

  activated: ->
    @focus()

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
    itemView = atom.views.getView(item)

    if itemPath = item.getPath?()
      @dataset.activeItemName = path.basename(itemPath)
      @dataset.activeItemPath = itemPath

    unless @itemViews.contains(itemView)
      @itemViews.appendChild(itemView)
      callAttachHooks(itemView)

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
    if viewToRemove = atom.views.getView(item)
      callRemoveHooks(viewToRemove) if destroyed
      viewToRemove.remove()

  paneDestroyed: ->
    @subscriptions.dispose()

  flexScaleChanged: (flexScale) ->
    @style.flexGrow = flexScale

  getActiveView: -> atom.views.getView(@model.getActiveItem())

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

atom.commands.add 'atom-workspace',
  'pane:show-next-item': -> @getModel().getActivePane().activateNextItem()
  'pane:show-previous-item': -> @getModel().getActivePane().activatePreviousItem()
  'pane:show-item-1': -> @getModel().getActivePane().activateItemAtIndex(0)
  'pane:show-item-2': -> @getModel().getActivePane().activateItemAtIndex(1)
  'pane:show-item-3': -> @getModel().getActivePane().activateItemAtIndex(2)
  'pane:show-item-4': -> @getModel().getActivePane().activateItemAtIndex(3)
  'pane:show-item-5': -> @getModel().getActivePane().activateItemAtIndex(4)
  'pane:show-item-6': -> @getModel().getActivePane().activateItemAtIndex(5)
  'pane:show-item-7': -> @getModel().getActivePane().activateItemAtIndex(6)
  'pane:show-item-8': -> @getModel().getActivePane().activateItemAtIndex(7)
  'pane:show-item-9': -> @getModel().getActivePane().activateItemAtIndex(8)
  'pane:move-item-right': -> @getModel().getActivePane().moveItemRight()
  'pane:move-item-left': -> @getModel().getActivePane().moveItemLeft()

atom.commands.add 'atom-pane',
  'pane:save-items': -> @getModel().saveItems()
  'pane:move-item-right': -> @getModel().moveItemRight()
  'pane:move-item-left': -> @getModel().moveItemLeft()
  'pane:split-left': -> @getModel().splitLeft(copyActiveItem: true)
  'pane:split-right': -> @getModel().splitRight(copyActiveItem: true)
  'pane:split-up': -> @getModel().splitUp(copyActiveItem: true)
  'pane:split-down': -> @getModel().splitDown(copyActiveItem: true)
  'pane:close': -> @getModel().close()
  'pane:close-other-items': -> @getModel().destroyInactiveItems()

module.exports = PaneElement = document.registerElement 'atom-pane', prototype: PaneElement.prototype
