module.exports =
class ItemRegistry
  constructor: ->
    @items = new WeakSet

  addItem: (item) ->
    if @hasItem(item)
      throw new Error("The workspace can only contain one instance of item #{item}")
    @items.add(item)

  removeItem: (item) ->
    @items.delete(item)

  hasItem: (item) ->
    @items.has(item)
