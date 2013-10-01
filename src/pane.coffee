{Model} = require 'telepath'

PaneAxis = require './pane-axis'

module.exports =
class Pane extends Model
  @resolve 'allComponents', 'allItems'

  @properties
    parentId: null
    activeItemId: null

  @relatesToOne 'parent', -> @allComponents.where(id: @parentId)
  @hasMany 'items', orderBy: 'itemLocation'
  @relatesToOne 'activeItem', -> @items.where(id: @activeItemId)
  
  @condition
    when: -> @items.$length.becomes(0)
    call: 'destroy'

  afterAttach: ->
    @activeItemId ?= @items.getFirst()?.get('id')

  addItem: (item) ->
    @items.add(item)

  showItem: (item) ->
    item = @addItem(item) unless @items.contains(item)
    @activeItemId = item.get('id')
    item

  moveItem: (item, index) ->
    @items.move(item, index)
    
  moveItemToPane: (item, targetPane, targetIndex) ->
    targetIndex ?= targetPane.items.length
    values = targetPane.items.inferValuesForIndex(targetIndex)
    values.paneId = targetPane.id
    item.set(values)

  splitLeft: (items...) ->
    @split('before', 'horizontal', items)

  splitRight: (items...) ->
    @split('after', 'horizontal', items)

  splitUp: (items...) ->
    @split('before', 'vertical', items)

  splitDown: (items...) ->
    @split('after', 'vertical', items)

  split: (side, orientation, items) ->
    if @parent?.orientation isnt orientation
      axis = new PaneAxis({@parentId, orientation})
      axis = @allComponents.insertBefore(this, axis)
      @parentId = axis.id

    newPane = new Pane({@parentId, items})
    switch side
      when 'before'
        @allComponents.insertBefore(this, newPane)
      when 'after'
        @allComponents.insertAfter(this, newPane)
