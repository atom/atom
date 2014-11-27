{CompositeDisposable} = require 'event-kit'
{$, callAttachHooks, callRemoveHooks} = require './space-pen-extensions'
PaneView = require './pane-view'

class PaneElement extends HTMLElement
  attached: false

  createdCallback: ->
    @attached = false
    @subscriptions = new CompositeDisposable
    @inlineDisplayStyles = new WeakMap

    @initializeContent()
    @subscribeToDOMEvents()
    @createSpacePenShim()

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

    @addEventListener 'focus', handleFocus, true
    @addEventListener 'blur', handleBlur, true

  createSpacePenShim: ->
    @__spacePenView = new PaneView(this)

  getModel: -> @model

  setModel: (@model) ->
    @subscriptions.add @model.onDidActivate(@activated.bind(this))
    @subscriptions.add @model.observeActive(@activeStatusChanged.bind(this))
    @subscriptions.add @model.observeActiveItem(@activeItemChanged.bind(this))
    @subscriptions.add @model.onDidRemoveItem(@itemRemoved.bind(this))
    @subscriptions.add @model.onDidDestroy(@paneDestroyed.bind(this))
    @__spacePenView.setModel(@model)

  activated: ->
    @focus()

  activeStatusChanged: (active) ->
    if active
      @classList.add('active')
    else
      @classList.remove('active')

  activeItemChanged: (item) ->
    return unless item?

    hasFocus = @hasFocus()
    itemView = @model.getView(item)

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
    if viewToRemove = @model.getView(item)
      callRemoveHooks(viewToRemove) if destroyed
      viewToRemove.remove()

  paneDestroyed: ->
    @subscriptions.dispose()

  getActiveView: -> @model.getView(@model.getActiveItem())

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

atom.commands.add 'atom-pane',
  'pane:save-items': -> @getModel().saveItems()
  'pane:show-next-item': -> @getModel().activateNextItem()
  'pane:show-previous-item': -> @getModel().activatePreviousItem()
  'pane:show-item-1': -> @getModel().activateItemAtIndex(0)
  'pane:show-item-2': -> @getModel().activateItemAtIndex(1)
  'pane:show-item-3': -> @getModel().activateItemAtIndex(2)
  'pane:show-item-4': -> @getModel().activateItemAtIndex(3)
  'pane:show-item-5': -> @getModel().activateItemAtIndex(4)
  'pane:show-item-6': -> @getModel().activateItemAtIndex(5)
  'pane:show-item-7': -> @getModel().activateItemAtIndex(6)
  'pane:show-item-8': -> @getModel().activateItemAtIndex(7)
  'pane:show-item-9': -> @getModel().activateItemAtIndex(8)
  'pane:move-item-right': -> @getModel().moveItemRight()
  'pane:move-item-left': -> @getModel().moveItemLeft()
  'pane:split-left': -> @getModel().splitLeft(copyActiveItem: true)
  'pane:split-right': -> @getModel().splitRight(copyActiveItem: true)
  'pane:split-up': -> @getModel().splitUp(copyActiveItem: true)
  'pane:split-down': -> @getModel().splitDown(copyActiveItem: true)
  'pane:close': -> @getModel().close()
  'pane:close-other-items': -> @getModel().destroyInactiveItems()

module.exports = PaneElement = document.registerElement 'atom-pane', prototype: PaneElement.prototype
