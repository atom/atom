{find, compact, clone} = require 'underscore-plus'
{Model} = require 'theorist'
Serializable = require 'serializable'

module.exports =
class PaneModel extends Model
  Serializable.includeInto(this)

  @properties
    activeItem: null

  constructor: ({@items, @activeItem}) ->
    @items ?= []
    @activeItem ?= @items[0]

  serializeParams: ->
    items: compact(@items.map((item) -> item.serialize?()))
    activeItemUri: @activeItem?.getUri?()

  deserializeParams: (params) ->
    {items, activeItemUri} = params
    params.items = items.map (itemState) -> atom.deserializers.deserialize(itemState)
    params.activeItem = find params.items, (item) -> item.getUri?() is activeItemUri
    params

  # Public: Returns all contained views.
  getItems: ->
    clone(@items)

  # Public: Returns the item at the specified index.
  itemAtIndex: (index) ->
    @items[index]

  # Public: Switches to the next contained item.
  showNextItem: =>
    index = @getActiveItemIndex()
    if index < @items.length - 1
      @showItemAtIndex(index + 1)
    else
      @showItemAtIndex(0)

  # Public: Switches to the previous contained item.
  showPreviousItem: =>
    index = @getActiveItemIndex()
    if index > 0
      @showItemAtIndex(index - 1)
    else
      @showItemAtIndex(@items.length - 1)

  # Public: Returns the index of the currently active item.
  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  # Public: Switch to the item associated with the given index.
  showItemAtIndex: (index) ->
    @showItem(@itemAtIndex(index))

  # Public: Focuses the given item.
  showItem: (item) ->
    if item?
      @addItem(item)
      @activeItem = item

  # Public: Add an additional item at the specified index.
  addItem: (item, index=@getActiveItemIndex() + 1) ->
    return if item in @items

    @items.splice(index, 0, item)
    @emit 'item-added', item, index
    item

  # Public:
  removeItem: (item, detach) ->
    index = @items.indexOf(item)
    @removeItemAtIndex(index, detach) if index >= 0

  # Public: Just remove the item at the given index.
  removeItemAtIndex: (index, detach) ->
    item = @items[index]
    @showNextItem() if item is @activeItem and @items.length > 1
    @items.splice(index, 1)
    @emit 'item-removed', item, index, detach

  # Public: Moves the given item to a the new index.
  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    @items.splice(oldIndex, 1)
    @items.splice(newIndex, 0, item)
    @emit 'item-moved', item, newIndex

  # Public: Moves the given item to another pane.
  moveItemToPane: (item, pane, index) ->
    pane.addItem(item, index)
    @removeItem(item, true)
