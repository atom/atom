{find, compact, extend, last} = require 'underscore-plus'
{Model, Sequence} = require 'theorist'
Serializable = require 'serializable'
PaneAxis = require './pane-axis'
Editor = require './editor'
PaneView = null

# Extended: A container for multiple items, one of which is *active* at a given
# time. With the default packages, a tab is displayed for each item and the
# active item's view is displayed.
#
# ## Events
# ### activated
#
# Extended: Emit when this pane as been activated
#
# ### item-added
#
# Extended: Emit when an item was added to the pane
#
# * `item` The pane item that has been added
# * `index` {Number} Index in the pane
#
# ### before-item-destroyed
#
# Extended: Emit before the item is destroyed
#
# * `item` The pane item that will be destoryed
#
# ### item-removed
#
# Extended: Emit when the item was removed from the pane
#
# * `item` The pane item that was removed
# * `index` {Number} Index in the pane
# * `destroying` {Boolean} `true` when the item is being removed because of destruction
#
# ### item-moved
#
# Extended: Emit when an item was moved within the pane
#
# * `item` The pane item that was moved
# * `newIndex` {Number} Index that the item was moved to
#
module.exports =
class Pane extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    container: undefined
    activeItem: undefined
    focused: false

  # Public: Only one pane is considered *active* at a time. A pane is activated
  # when it is focused, and when focus returns to the pane container after
  # moving to another element such as a panel, it returns to the active pane.
  @behavior 'active', ->
    @$container
      .switch((container) -> container?.$activePane)
      .map((activePane) => activePane is this)
      .distinctUntilChanged()

  constructor: (params) ->
    super

    @items = Sequence.fromArray(compact(params?.items ? []))
    @activeItem ?= @items[0]

    @subscribe @items.onEach (item) =>
      if typeof item.on is 'function'
        @subscribe item, 'destroyed', => @removeItem(item, true)

    @subscribe @items.onRemoval (item, index) =>
      @unsubscribe item if typeof item.on is 'function'

  # Called by the Serializable mixin during serialization.
  serializeParams: ->
    id: @id
    items: compact(@items.map((item) -> item.serialize?()))
    activeItemUri: @activeItem?.getUri?()
    focused: @focused

  # Called by the Serializable mixin during deserialization.
  deserializeParams: (params) ->
    {items, activeItemUri} = params
    params.items = compact(items.map (itemState) -> atom.deserializers.deserialize(itemState))
    params.activeItem = find params.items, (item) -> item.getUri?() is activeItemUri
    params

  # Called by the view layer to construct a view for this model.
  getViewClass: -> PaneView ?= require './pane-view'

  isActive: -> @active

  # Called by the view layer to indicate that the pane has gained focus.
  focus: ->
    @focused = true
    @activate() unless @isActive()

  # Called by the view layer to indicate that the pane has lost focus.
  blur: ->
    @focused = false
    true # if this is called from an event handler, don't cancel it

  # Public: Makes this pane the *active* pane, causing it to gain focus
  # immediately.
  activate: ->
    @container?.activePane = this
    @emit 'activated'

  getPanes: -> [this]

  # Public: Get the items in this pane.
  #
  # Returns an {Array} of items.
  getItems: ->
    @items.slice()

  # Public: Get the active pane item in this pane.
  #
  # Returns a pane item.
  getActiveItem: ->
    @activeItem

  # Public: Returns an {Editor} if the pane item is an {Editor}, or null
  # otherwise.
  getActiveEditor: ->
    @activeItem if @activeItem instanceof Editor

  # Public: Returns the item at the specified index.
  itemAtIndex: (index) ->
    @items[index]

  # Public: Makes the next item active.
  activateNextItem: ->
    index = @getActiveItemIndex()
    if index < @items.length - 1
      @activateItemAtIndex(index + 1)
    else
      @activateItemAtIndex(0)

  # Public: Makes the previous item active.
  activatePreviousItem: ->
    index = @getActiveItemIndex()
    if index > 0
      @activateItemAtIndex(index - 1)
    else
      @activateItemAtIndex(@items.length - 1)

  # Returns the index of the current active item.
  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  # Makes the item at the given index active.
  activateItemAtIndex: (index) ->
    @activateItem(@itemAtIndex(index))

  # Makes the given item active, adding the item if necessary.
  activateItem: (item) ->
    if item?
      @addItem(item)
      @activeItem = item

  # Public: Adds the item to the pane.
  #
  # * `item` The item to add. It can be a model with an associated view or a view.
  # * `index` (optional) {Number} at which to add the item. If omitted, the item is
  #   added after the current active item.
  #
  # Returns the added item
  addItem: (item, index=@getActiveItemIndex() + 1) ->
    return if item in @items

    @items.splice(index, 0, item)
    @emit 'item-added', item, index
    @activeItem ?= item
    item

  # Public: Adds the given items to the pane.
  #
  # * `items` An {Array} of items to add. Items can be models with associated
  #   views or views. Any items that are already present in items will
  #   not be added.
  # * `index` (optional) {Number} index at which to add the item. If omitted, the item is
  #   added after the current active item.
  #
  # Returns an {Array} of the added items
  addItems: (items, index=@getActiveItemIndex() + 1) ->
    items = items.filter (item) => not (item in @items)
    @addItem(item, index + i) for item, i in items
    items

  removeItem: (item, destroying) ->
    index = @items.indexOf(item)
    return if index is -1
    if item is @activeItem
      if @items.length is 1
        @activeItem = undefined
      else if index is 0
        @activateNextItem()
      else
        @activatePreviousItem()
    @items.splice(index, 1)
    @emit 'item-removed', item, index, destroying
    @container?.itemDestroyed(item) if destroying
    @destroy() if @items.length is 0 and atom.config.get('core.destroyEmptyPanes')

  # Public: Moves the given item to the specified index.
  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    @items.splice(oldIndex, 1)
    @items.splice(newIndex, 0, item)
    @emit 'item-moved', item, newIndex

  # Public: Moves the given item to the given index at another pane.
  moveItemToPane: (item, pane, index) ->
    pane.addItem(item, index)
    @removeItem(item)

  # Public: Destroys the currently active item and make the next item active.
  destroyActiveItem: ->
    @destroyItem(@activeItem)
    false

  # Public: Destroys the given item. If it is the active item, activate the next
  # one. If this is the last item, also destroys the pane.
  destroyItem: (item) ->
    if item?
      @emit 'before-item-destroyed', item
      if @promptToSaveItem(item)
        @removeItem(item, true)
        item.destroy?()
        true
      else
        false

  # Public: Destroys all items and destroys the pane.
  destroyItems: ->
    @destroyItem(item) for item in @getItems()

  # Public: Destroys all items but the active one.
  destroyInactiveItems: ->
    @destroyItem(item) for item in @getItems() when item isnt @activeItem

  destroy: ->
    if @container?.isAlive() and @container.getPanes().length is 1
      @destroyItems()
    else
      super

  # Called by model superclass.
  destroyed: ->
    @container.activateNextPane() if @isActive()
    item.destroy?() for item in @items.slice()

  # Public: Prompts the user to save the given item if it can be saved and is
  # currently unsaved.
  promptToSaveItem: (item) ->
    return true unless item.shouldPromptToSave?()

    uri = item.getUri()
    chosen = atom.confirm
      message: "'#{item.getTitle?() ? item.getUri()}' has changes, do you want to save them?"
      detailedMessage: "Your changes will be lost if you close this item without saving."
      buttons: ["Save", "Cancel", "Don't Save"]

    switch chosen
      when 0 then @saveItem(item, -> true)
      when 1 then false
      when 2 then true

  # Public: Saves the active item.
  saveActiveItem: ->
    @saveItem(@activeItem)

  # Public: Saves the active item at a prompted-for location.
  saveActiveItemAs: ->
    @saveItemAs(@activeItem)

  # Public: Saves the specified item.
  #
  # * `item` The item to save.
  # * `nextAction` (optional) {Function} which will be called after the item is saved.
  saveItem: (item, nextAction) ->
    if item?.getUri?()
      item.save?()
      nextAction?()
    else
      @saveItemAs(item, nextAction)

  # Public: Saves the given item at a prompted-for location.
  #
  # * `item` The item to save.
  # * `nextAction` (optional) {Function} which will be called after the item is saved.
  saveItemAs: (item, nextAction) ->
    return unless item?.saveAs?

    itemPath = item.getPath?()
    newItemPath = atom.showSaveDialogSync(itemPath)
    if newItemPath
      item.saveAs(newItemPath)
      nextAction?()

  # Public: Saves all items.
  saveItems: ->
    @saveItem(item) for item in @getItems()

  # Public: Returns the first item that matches the given URI or undefined if
  # none exists.
  itemForUri: (uri) ->
    find @items, (item) -> item.getUri?() is uri

  # Public: Activates the first item that matches the given URI. Returns a
  # boolean indicating whether a matching item was found.
  activateItemForUri: (uri) ->
    if item = @itemForUri(uri)
      @activateItem(item)
      true
    else
      false

  copyActiveItem: ->
    if @activeItem?
      @activeItem.copy?() ? atom.deserializers.deserialize(@activeItem.serialize())

  # Public: Creates a new pane to the left of the receiver.
  #
  # * `params` {Object} with keys
  #   * `items` (optional) {Array} of items with which to construct the new pane.
  #
  # Returns the new {Pane}.
  splitLeft: (params) ->
    @split('horizontal', 'before', params)

  # Public: Creates a new pane to the right of the receiver.
  #
  # * `params` {Object} with keys:
  #   * `items` (optional) {Array} of items with which to construct the new pane.
  #
  # Returns the new {Pane}.
  splitRight: (params) ->
    @split('horizontal', 'after', params)

  # Public: Creates a new pane above the receiver.
  #
  # * `params` {Object} with keys:
  #   * `items` (optional) {Array} of items with which to construct the new pane.
  #
  # Returns the new {Pane}.
  splitUp: (params) ->
    @split('vertical', 'before', params)

  # Public: Creates a new pane below the receiver.
  #
  # * `params` {Object} with keys:
  #   * `items` (optional) {Array} of items with which to construct the new pane.
  #
  # Returns the new {Pane}.
  splitDown: (params) ->
    @split('vertical', 'after', params)

  split: (orientation, side, params) ->
    if @parent.orientation isnt orientation
      @parent.replaceChild(this, new PaneAxis({@container, orientation, children: [this]}))

    newPane = new @constructor(params)
    switch side
      when 'before' then @parent.insertChildBefore(this, newPane)
      when 'after' then @parent.insertChildAfter(this, newPane)

    newPane.activate()
    newPane

  # If the parent is a horizontal axis, returns its first child if it is a pane;
  # otherwise returns this pane.
  findLeftmostSibling: ->
    if @parent.orientation is 'horizontal'
      [leftmostSibling] = @parent.children
      if leftmostSibling instanceof PaneAxis
        this
      else
        leftmostSibling
    else
      this

  # If the parent is a horizontal axis, returns its last child if it is a pane;
  # otherwise returns a new pane created by splitting this pane rightward.
  findOrCreateRightmostSibling: ->
    if @parent.orientation is 'horizontal'
      rightmostSibling = last(@parent.children)
      if rightmostSibling instanceof PaneAxis
        @splitRight()
      else
        rightmostSibling
    else
      @splitRight()
