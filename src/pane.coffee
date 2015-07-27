{find, compact, extend, last} = require 'underscore-plus'
{Emitter} = require 'event-kit'
Serializable = require 'serializable'
Grim = require 'grim'
Model = require './model'
PaneAxis = require './pane-axis'
TextEditor = require './text-editor'

# Extended: A container for presenting content in the center of the workspace.
# Panes can contain multiple items, one of which is *active* at a given time.
# The view corresponding to the active item is displayed in the interface. In
# the default configuration, tabs are also displayed for each item.
module.exports =
class Pane extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  constructor: (params) ->
    super

    unless Grim.includeDeprecatedAPIs
      @container = params?.container
      @activeItem = params?.activeItem

    @emitter = new Emitter
    @itemSubscriptions = new WeakMap
    @items = []

    @addItems(compact(params?.items ? []))
    @setActiveItem(@items[0]) unless @getActiveItem()?
    @setFlexScale(params?.flexScale ? 1)

  # Called by the Serializable mixin during serialization.
  serializeParams: ->
    if typeof @activeItem?.getURI is 'function'
      activeItemURI = @activeItem.getURI()
    else if Grim.includeDeprecatedAPIs and typeof @activeItem?.getUri is 'function'
      activeItemURI = @activeItem.getUri()

    id: @id
    items: compact(@items.map((item) -> item.serialize?()))
    activeItemURI: activeItemURI
    focused: @focused
    flexScale: @flexScale

  # Called by the Serializable mixin during deserialization.
  deserializeParams: (params) ->
    {items, activeItemURI, activeItemUri} = params
    activeItemURI ?= activeItemUri
    params.items = compact(items.map (itemState) -> atom.deserializers.deserialize(itemState))
    params.activeItem = find params.items, (item) ->
      if typeof item.getURI is 'function'
        itemURI = item.getURI()
      else if Grim.includeDeprecatedAPIs and typeof item.getUri is 'function'
        itemURI = item.getUri()

      itemURI is activeItemURI
    params

  getParent: -> @parent

  setParent: (@parent) -> @parent

  getContainer: -> @container

  setContainer: (container) ->
    unless container is @container
      @container = container
      container.didAddPane({pane: this})

  setFlexScale: (@flexScale) ->
    @emitter.emit 'did-change-flex-scale', @flexScale
    @flexScale

  getFlexScale: -> @flexScale
  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the pane resize
  #
  # the callback will be invoked when pane's flexScale property changes
  #
  # * `callback` {Function} to be called when the pane is resized
  #
  # Returns a {Disposable} on which '.dispose()' can be called to unsubscribe.
  onDidChangeFlexScale: (callback) ->
    @emitter.on 'did-change-flex-scale', callback

  # Public: Invoke the given callback with all current and future items.
  #
  # * `callback` {Function} to be called with current and future items.
  #   * `item` An item that is present in {::getItems} at the time of
  #     subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeFlexScale: (callback) ->
    callback(@flexScale)
    @onDidChangeFlexScale(callback)

  # Public: Invoke the given callback when the pane is activated.
  #
  # The given callback will be invoked whenever {::activate} is called on the
  # pane, even if it is already active at the time.
  #
  # * `callback` {Function} to be called when the pane is activated.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivate: (callback) ->
    @emitter.on 'did-activate', callback

  # Public: Invoke the given callback before the pane is destroyed.
  #
  # * `callback` {Function} to be called before the pane is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillDestroy: (callback) ->
    @emitter.on 'will-destroy', callback

  # Public: Invoke the given callback when the pane is destroyed.
  #
  # * `callback` {Function} to be called when the pane is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Public: Invoke the given callback when the value of the {::isActive}
  # property changes.
  #
  # * `callback` {Function} to be called when the value of the {::isActive}
  #   property changes.
  #   * `active` {Boolean} indicating whether the pane is active.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActive: (callback) ->
    @container.onDidChangeActivePane (activePane) =>
      callback(this is activePane)

  # Public: Invoke the given callback with the current and future values of the
  # {::isActive} property.
  #
  # * `callback` {Function} to be called with the current and future values of
  #   the {::isActive} property.
  #   * `active` {Boolean} indicating whether the pane is active.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActive: (callback) ->
    callback(@isActive())
    @onDidChangeActive(callback)

  # Public: Invoke the given callback when an item is added to the pane.
  #
  # * `callback` {Function} to be called with when items are added.
  #   * `event` {Object} with the following keys:
  #     * `item` The added pane item.
  #     * `index` {Number} indicating where the item is located.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddItem: (callback) ->
    @emitter.on 'did-add-item', callback

  # Public: Invoke the given callback when an item is removed from the pane.
  #
  # * `callback` {Function} to be called with when items are removed.
  #   * `event` {Object} with the following keys:
  #     * `item` The removed pane item.
  #     * `index` {Number} indicating where the item was located.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveItem: (callback) ->
    @emitter.on 'did-remove-item', callback

  # Public: Invoke the given callback before an item is removed from the pane.
  #
  # * `callback` {Function} to be called with when items are removed.
  #   * `event` {Object} with the following keys:
  #     * `item` The pane item to be removed.
  #     * `index` {Number} indicating where the item is located.
  onWillRemoveItem: (callback) ->
    @emitter.on 'will-remove-item', callback

  # Public: Invoke the given callback when an item is moved within the pane.
  #
  # * `callback` {Function} to be called with when items are moved.
  #   * `event` {Object} with the following keys:
  #     * `item` The removed pane item.
  #     * `oldIndex` {Number} indicating where the item was located.
  #     * `newIndex` {Number} indicating where the item is now located.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidMoveItem: (callback) ->
    @emitter.on 'did-move-item', callback

  # Public: Invoke the given callback with all current and future items.
  #
  # * `callback` {Function} to be called with current and future items.
  #   * `item` An item that is present in {::getItems} at the time of
  #     subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeItems: (callback) ->
    callback(item) for item in @getItems()
    @onDidAddItem ({item}) -> callback(item)

  # Public: Invoke the given callback when the value of {::getActiveItem}
  # changes.
  #
  # * `callback` {Function} to be called with when the active item changes.
  #   * `activeItem` The current active item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveItem: (callback) ->
    @emitter.on 'did-change-active-item', callback

  # Public: Invoke the given callback with the current and future values of
  # {::getActiveItem}.
  #
  # * `callback` {Function} to be called with the current and future active
  #   items.
  #   * `activeItem` The current active item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveItem: (callback) ->
    callback(@getActiveItem())
    @onDidChangeActiveItem(callback)

  # Public: Invoke the given callback before items are destroyed.
  #
  # * `callback` {Function} to be called before items are destroyed.
  #   * `event` {Object} with the following keys:
  #     * `item` The item that will be destroyed.
  #     * `index` The location of the item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to
  # unsubscribe.
  onWillDestroyItem: (callback) ->
    @emitter.on 'will-destroy-item', callback

  # Called by the view layer to indicate that the pane has gained focus.
  focus: ->
    @focused = true
    @activate() unless @isActive()

  # Called by the view layer to indicate that the pane has lost focus.
  blur: ->
    @focused = false
    true # if this is called from an event handler, don't cancel it

  isFocused: -> @focused

  getPanes: -> [this]

  unsubscribeFromItem: (item) ->
    @itemSubscriptions.get(item)?.dispose()
    @itemSubscriptions.delete(item)

  ###
  Section: Items
  ###

  # Public: Get the items in this pane.
  #
  # Returns an {Array} of items.
  getItems: ->
    @items.slice()

  # Public: Get the active pane item in this pane.
  #
  # Returns a pane item.
  getActiveItem: -> @activeItem

  setActiveItem: (activeItem) ->
    unless activeItem is @activeItem
      @activeItem = activeItem
      @emitter.emit 'did-change-active-item', @activeItem
    @activeItem

  # Return an {TextEditor} if the pane item is an {TextEditor}, or null otherwise.
  getActiveEditor: ->
    @activeItem if @activeItem instanceof TextEditor

  # Public: Return the item at the given index.
  #
  # * `index` {Number}
  #
  # Returns an item or `null` if no item exists at the given index.
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

  # Public: Move the active tab to the right.
  moveItemRight: ->
    index = @getActiveItemIndex()
    rightItemIndex = index + 1
    @moveItem(@getActiveItem(), rightItemIndex) unless rightItemIndex > @items.length - 1

  # Public: Move the active tab to the left
  moveItemLeft: ->
    index = @getActiveItemIndex()
    leftItemIndex = index - 1
    @moveItem(@getActiveItem(), leftItemIndex) unless leftItemIndex < 0

  # Public: Get the index of the active item.
  #
  # Returns a {Number}.
  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  # Public: Activate the item at the given index.
  #
  # * `index` {Number}
  activateItemAtIndex: (index) ->
    @activateItem(@itemAtIndex(index))

  # Public: Make the given item *active*, causing it to be displayed by
  # the pane's view.
  activateItem: (item) ->
    if item?
      @addItem(item)
      @setActiveItem(item)

  # Public: Add the given item to the pane.
  #
  # * `item` The item to add. It can be a model with an associated view or a
  #   view.
  # * `index` (optional) {Number} indicating the index at which to add the item.
  #   If omitted, the item is added after the current active item.
  #
  # Returns the added item.
  addItem: (item, index=@getActiveItemIndex() + 1) ->
    throw new Error("Pane items must be objects. Attempted to add item #{item}.") unless item? and typeof item is 'object'

    return if item in @items

    if typeof item.onDidDestroy is 'function'
      @itemSubscriptions.set item, item.onDidDestroy => @removeItem(item, true)
    else if Grim.includeDeprecatedAPIs and typeof item.on is 'function'
      @subscribe item, 'destroyed', => @removeItem(item, true)

    @items.splice(index, 0, item)
    @emit 'item-added', item, index if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-add-item', {item, index}
    @setActiveItem(item) unless @getActiveItem()?
    item

  # Public: Add the given items to the pane.
  #
  # * `items` An {Array} of items to add. Items can be views or models with
  #   associated views. Any objects that are already present in the pane's
  #   current items will not be added again.
  # * `index` (optional) {Number} index at which to add the items. If omitted,
  #   the item is #   added after the current active item.
  #
  # Returns an {Array} of added items.
  addItems: (items, index=@getActiveItemIndex() + 1) ->
    items = items.filter (item) => not (item in @items)
    @addItem(item, index + i) for item, i in items
    items

  removeItem: (item, destroyed=false) ->
    index = @items.indexOf(item)
    return if index is -1

    @emitter.emit 'will-remove-item', {item, index, destroyed}

    if Grim.includeDeprecatedAPIs and typeof item.on is 'function'
      @unsubscribe item
    @unsubscribeFromItem(item)

    if item is @activeItem
      if @items.length is 1
        @setActiveItem(undefined)
      else if index is 0
        @activateNextItem()
      else
        @activatePreviousItem()
    @items.splice(index, 1)
    @emit 'item-removed', item, index, destroyed if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-remove-item', {item, index, destroyed}
    @container?.didDestroyPaneItem({item, index, pane: this}) if destroyed
    @destroy() if @items.length is 0 and atom.config.get('core.destroyEmptyPanes')

  # Public: Move the given item to the given index.
  #
  # * `item` The item to move.
  # * `index` {Number} indicating the index to which to move the item.
  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    @items.splice(oldIndex, 1)
    @items.splice(newIndex, 0, item)
    @emit 'item-moved', item, newIndex if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-move-item', {item, oldIndex, newIndex}

  # Public: Move the given item to the given index on another pane.
  #
  # * `item` The item to move.
  # * `pane` {Pane} to which to move the item.
  # * `index` {Number} indicating the index to which to move the item in the
  #   given pane.
  moveItemToPane: (item, pane, index) ->
    @removeItem(item)
    pane.addItem(item, index)

  # Public: Destroy the active item and activate the next item.
  destroyActiveItem: ->
    @destroyItem(@activeItem)
    false

  # Public: Destroy the given item.
  #
  # If the item is active, the next item will be activated. If the item is the
  # last item, the pane will be destroyed if the `core.destroyEmptyPanes` config
  # setting is `true`.
  #
  # * `item` Item to destroy
  destroyItem: (item) ->
    index = @items.indexOf(item)
    if index isnt -1
      @emit 'before-item-destroyed', item if Grim.includeDeprecatedAPIs
      @emitter.emit 'will-destroy-item', {item, index}
      @container?.willDestroyPaneItem({item, index, pane: this})
      if @promptToSaveItem(item)
        @removeItem(item, true)
        item.destroy?()
        true
      else
        false

  # Public: Destroy all items.
  destroyItems: ->
    @destroyItem(item) for item in @getItems()
    return

  # Public: Destroy all items except for the active item.
  destroyInactiveItems: ->
    @destroyItem(item) for item in @getItems() when item isnt @activeItem
    return

  promptToSaveItem: (item, options={}) ->
    return true unless item.shouldPromptToSave?(options)

    if typeof item.getURI is 'function'
      uri = item.getURI()
    else if typeof item.getUri is 'function'
      uri = item.getUri()
    else
      return true

    chosen = atom.confirm
      message: "'#{item.getTitle?() ? uri}' has changes, do you want to save them?"
      detailedMessage: "Your changes will be lost if you close this item without saving."
      buttons: ["Save", "Cancel", "Don't Save"]

    switch chosen
      when 0 then @saveItem(item, -> true)
      when 1 then false
      when 2 then true

  # Public: Save the active item.
  saveActiveItem: (nextAction) ->
    @saveItem(@getActiveItem(), nextAction)

  # Public: Prompt the user for a location and save the active item with the
  # path they select.
  #
  # * `nextAction` (optional) {Function} which will be called after the item is
  #   successfully saved.
  saveActiveItemAs: (nextAction) ->
    @saveItemAs(@getActiveItem(), nextAction)

  # Public: Save the given item.
  #
  # * `item` The item to save.
  # * `nextAction` (optional) {Function} which will be called after the item is
  #   successfully saved.
  saveItem: (item, nextAction) ->
    if typeof item?.getURI is 'function'
      itemURI = item.getURI()
    else if typeof item?.getUri is 'function'
      itemURI = item.getUri()

    if itemURI?
      try
        item.save?()
      catch error
        @handleSaveError(error, item)
      nextAction?()
    else
      @saveItemAs(item, nextAction)

  # Public: Prompt the user for a location and save the active item with the
  # path they select.
  #
  # * `item` The item to save.
  # * `nextAction` (optional) {Function} which will be called after the item is
  #   successfully saved.
  saveItemAs: (item, nextAction) ->
    return unless item?.saveAs?

    saveOptions = item.getSaveDialogOptions?() ? {}
    saveOptions.defaultPath ?= item.getPath()
    newItemPath = atom.showSaveDialogSync(saveOptions)
    if newItemPath
      try
        item.saveAs(newItemPath)
      catch error
        @handleSaveError(error, item)
      nextAction?()

  # Public: Save all items.
  saveItems: ->
    @saveItem(item) for item in @getItems()
    return

  # Public: Return the first item that matches the given URI or undefined if
  # none exists.
  #
  # * `uri` {String} containing a URI.
  itemForURI: (uri) ->
    find @items, (item) ->
      if typeof item.getURI is 'function'
        itemUri = item.getURI()
      else if typeof item.getUri is 'function'
        itemUri = item.getUri()

      itemUri is uri

  # Public: Activate the first item that matches the given URI.
  #
  # Returns a {Boolean} indicating whether an item matching the URI was found.
  activateItemForURI: (uri) ->
    if item = @itemForURI(uri)
      @activateItem(item)
      true
    else
      false

  copyActiveItem: ->
    if @activeItem?
      @activeItem.copy?() ? atom.deserializers.deserialize(@activeItem.serialize())

  ###
  Section: Lifecycle
  ###

  # Public: Determine whether the pane is active.
  #
  # Returns a {Boolean}.
  isActive: ->
    @container?.getActivePane() is this

  # Public: Makes this pane the *active* pane, causing it to gain focus.
  activate: ->
    throw new Error("Pane has been destroyed") if @isDestroyed()

    @container?.setActivePane(this)
    @emit 'activated' if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-activate'

  # Public: Close the pane and destroy all its items.
  #
  # If this is the last pane, all the items will be destroyed but the pane
  # itself will not be destroyed.
  destroy: ->
    if @container?.isAlive() and @container.getPanes().length is 1
      @destroyItems()
    else
      @emitter.emit 'will-destroy'
      @container?.willDestroyPane(pane: this)
      super

  # Called by model superclass.
  destroyed: ->
    @container.activateNextPane() if @isActive()
    @emitter.emit 'did-destroy'
    @emitter.dispose()
    item.destroy?() for item in @items.slice()
    @container?.didDestroyPane(pane: this)

  ###
  Section: Splitting
  ###

  # Public: Create a new pane to the left of this pane.
  #
  # * `params` (optional) {Object} with the following keys:
  #   * `items` (optional) {Array} of items to add to the new pane.
  #   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  #
  # Returns the new {Pane}.
  splitLeft: (params) ->
    @split('horizontal', 'before', params)

  # Public: Create a new pane to the right of this pane.
  #
  # * `params` (optional) {Object} with the following keys:
  #   * `items` (optional) {Array} of items to add to the new pane.
  #   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  #
  # Returns the new {Pane}.
  splitRight: (params) ->
    @split('horizontal', 'after', params)

  # Public: Creates a new pane above the receiver.
  #
  # * `params` (optional) {Object} with the following keys:
  #   * `items` (optional) {Array} of items to add to the new pane.
  #   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  #
  # Returns the new {Pane}.
  splitUp: (params) ->
    @split('vertical', 'before', params)

  # Public: Creates a new pane below the receiver.
  #
  # * `params` (optional) {Object} with the following keys:
  #   * `items` (optional) {Array} of items to add to the new pane.
  #   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  #
  # Returns the new {Pane}.
  splitDown: (params) ->
    @split('vertical', 'after', params)

  split: (orientation, side, params) ->
    if params?.copyActiveItem
      params.items ?= []
      params.items.push(@copyActiveItem())

    if @parent.orientation isnt orientation
      @parent.replaceChild(this, new PaneAxis({@container, orientation, children: [this], @flexScale}))
      @setFlexScale(1)

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

  close: ->
    @destroy() if @confirmClose()

  confirmClose: ->
    for item in @getItems()
      return false unless @promptToSaveItem(item)
    true

  handleSaveError: (error, item) ->
    itemPath = error.path ? item?.getPath?()
    addWarningWithPath = (message, options) ->
      message = "#{message} '#{itemPath}'" if itemPath
      atom.notifications.addWarning(message, options)

    if error.code is 'EISDIR' or error.message?.endsWith?('is a directory')
      atom.notifications.addWarning("Unable to save file: #{error.message}")
    else if error.code is 'EACCES'
      addWarningWithPath('Unable to save file: Permission denied')
    else if error.code in ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST']
      addWarningWithPath('Unable to save file', detail: error.message)
    else if error.code is 'EROFS'
      addWarningWithPath('Unable to save file: Read-only file system')
    else if error.code is 'ENOSPC'
      addWarningWithPath('Unable to save file: No space left on device')
    else if error.code is 'ENXIO'
      addWarningWithPath('Unable to save file: No such device or address')
    else if error.code is 'ENOTSUP'
      addWarningWithPath('Unable to save file: Operation not supported on socket')
    else if error.code is 'EIO'
      addWarningWithPath('Unable to save file: I/O error writing file')
    else if error.code is 'EINTR'
      addWarningWithPath('Unable to save file: Interrupted system call')
    else if error.code is 'ECONNRESET'
      addWarningWithPath('Unable to save file: Connection reset')
    else if error.code is 'ESPIPE'
      addWarningWithPath('Unable to save file: Invalid seek')
    else if errorMatch = /ENOTDIR, not a directory '([^']+)'/.exec(error.message)
      fileName = errorMatch[1]
      atom.notifications.addWarning("Unable to save file: A directory in the path '#{fileName}' could not be written to")
    else
      throw error

if Grim.includeDeprecatedAPIs
  Pane.properties
    container: undefined
    activeItem: undefined
    focused: false

  Pane.behavior 'active', ->
    @$container
      .switch((container) -> container?.$activePane)
      .map((activePane) => activePane is this)
      .distinctUntilChanged()

  Pane::on = (eventName) ->
    switch eventName
      when 'activated'
        Grim.deprecate("Use Pane::onDidActivate instead")
      when 'destroyed'
        Grim.deprecate("Use Pane::onDidDestroy instead")
      when 'item-added'
        Grim.deprecate("Use Pane::onDidAddItem instead")
      when 'item-removed'
        Grim.deprecate("Use Pane::onDidRemoveItem instead")
      when 'item-moved'
        Grim.deprecate("Use Pane::onDidMoveItem instead")
      when 'before-item-destroyed'
        Grim.deprecate("Use Pane::onWillDestroyItem instead")
      else
        Grim.deprecate("Subscribing via ::on is deprecated. Use documented event subscription methods instead.")
    super

  Pane::behavior = (behaviorName) ->
    switch behaviorName
      when 'active'
        Grim.deprecate("The $active behavior property is deprecated. Use ::observeActive or ::onDidChangeActive instead.")
      when 'container'
        Grim.deprecate("The $container behavior property is deprecated.")
      when 'activeItem'
        Grim.deprecate("The $activeItem behavior property is deprecated. Use ::observeActiveItem or ::onDidChangeActiveItem instead.")
      when 'focused'
        Grim.deprecate("The $focused behavior property is deprecated.")
      else
        Grim.deprecate("Pane::behavior is deprecated. Use event subscription methods instead.")

    super

  Pane::itemForUri = (uri) ->
    Grim.deprecate("Use `::itemForURI` instead.")
    @itemForURI(uri)

  Pane::activateItemForUri = (uri) ->
    Grim.deprecate("Use `::activateItemForURI` instead.")
    @activateItemForURI(uri)
else
  Pane::container = undefined
  Pane::activeItem = undefined
  Pane::focused = undefined
