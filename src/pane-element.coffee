{CompositeDisposable} = require 'event-kit'
{$} = require './space-pen-extensions'

class PaneElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @initializeContent()
    @subscribeToDOMEvents()

  attachedCallback: ->
    @focus() if @model.isFocused()

  detachedCallback: ->
    @subscriptions.dispose()
    @model.destroy() unless @model.isDestroyed()

  initializeContent: ->
    @setAttribute 'class', 'pane'
    @setAttribute 'tabindex', -1
    @appendChild @itemViews = document.createElement('div')
    @itemViews.setAttribute 'class', 'item-views'

  subscribeToDOMEvents: ->
    @addEventListener 'focusin', => @model.focus()
    @addEventListener 'focusout', => @model.blur()
    @addEventListener 'focus', => @getActiveView()?.focus()

  getModel: -> @model

  setModel: (@model) ->
    @subscriptions.add @model.onDidActivate(@activated.bind(this))
    @subscriptions.add @model.observeActive(@activeStatusChanged.bind(this))
    @subscriptions.add @model.observeActiveItem(@activeItemChanged.bind(this))
    @subscriptions.add @model.onDidRemoveItem(@itemRemoved.bind(this))

  activated: ->
    @focus() unless @hasFocus()

  activeStatusChanged: (active) ->
    console.log this
    if active
      @classList.add('active')
    else
      @classList.remove('active')

  activeItemChanged: (item) ->
    return unless item?

    $itemViews = $(@itemViews)
    view = @model.getView(item).__spacePenView
    otherView.hide() for otherView in $itemViews.children().not(view).views()
    $itemViews.append(view) unless view.parent().is($itemViews)
    view.show()
    view.focus() if @hasFocus()

  itemRemoved: ({item, index, destroyed}) ->
    if item instanceof $
      viewToRemove = item
    else
      viewToRemove = @model.getView(item).__spacePenView

    if viewToRemove?
      if destroyed
        viewToRemove.remove()
      else
        viewToRemove.detach()

  getActiveView: -> @model.getView(@model.getActiveItem())

  hasFocus: ->
    {activeElement} = document
    this is activeElement or @contains(activeElement)

module.exports = PaneElement = document.registerElement 'atom-pane',
  prototype: PaneElement.prototype
  extends: 'div'

# handleEvents: ->
  # @command 'pane:save-items', => @saveItems()
  # @command 'pane:show-next-item', => @activateNextItem()
  # @command 'pane:show-previous-item', => @activatePreviousItem()
  #
  # @command 'pane:show-item-1', => @activateItemAtIndex(0)
  # @command 'pane:show-item-2', => @activateItemAtIndex(1)
  # @command 'pane:show-item-3', => @activateItemAtIndex(2)
  # @command 'pane:show-item-4', => @activateItemAtIndex(3)
  # @command 'pane:show-item-5', => @activateItemAtIndex(4)
  # @command 'pane:show-item-6', => @activateItemAtIndex(5)
  # @command 'pane:show-item-7', => @activateItemAtIndex(6)
  # @command 'pane:show-item-8', => @activateItemAtIndex(7)
  # @command 'pane:show-item-9', => @activateItemAtIndex(8)
  #
  # @command 'pane:split-left', => @model.splitLeft(copyActiveItem: true)
  # @command 'pane:split-right', => @model.splitRight(copyActiveItem: true)
  # @command 'pane:split-up', => @model.splitUp(copyActiveItem: true)
  # @command 'pane:split-down', => @model.splitDown(copyActiveItem: true)
  # @command 'pane:close', =>
  #   @model.destroyItems()
  #   @model.destroy()
  # @command 'pane:close-other-items', => @destroyInactiveItems()
