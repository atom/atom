{View} = require 'space-pen'
$ = require 'jquery'

module.exports =
class SortableList extends View
  @viewClass: -> 'sortable-list'

  initialize: ->
    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend', '.sortable', @onDragEnd
    @on 'dragover', @onDragOver
    @on 'drop', @onDrop

  onDragStart: (event) =>
    unless @shouldAllowDrag(event)
      event.preventDefault()
      return

    el = $(event.target).closest('.sortable')
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'sortable-index', el.index()

  onDragEnd: (event) =>
    @find(".is-dragging").removeClass 'is-dragging'

  onDragOver: (event) =>
    event.preventDefault()
    currentDropTargetIndex = @find(".is-drop-target").index()
    newDropTargetIndex = @getDropTargetIndex(event)

    if newDropTargetIndex != currentDropTargetIndex
      @children().removeClass 'is-drop-target drop-target-is-after'
      sortableObjects = @find(".sortable")
      if newDropTargetIndex < sortableObjects.length
        sortableObjects.eq(newDropTargetIndex).addClass 'is-drop-target'
      else
        sortableObjects.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'

  onDrop: (event) =>
    return false if !@shouldAllowDrop(event)
    event.stopPropagation()
    @children('.is-drop-target').removeClass 'is-drop-target'
    @children('.drop-target-is-after').removeClass 'drop-target-is-after'

  shouldAllowDrag: (event) ->
    true

  shouldAllowDrop: (event) ->
    true

  getDropTargetIndex: (event) ->
    el = $(event.target).closest('.sortable')
    el = $(event.target).find('.sortable').last()  if el.length == 0

    elementCenter = el.offset().left + el.width() / 2

    if event.originalEvent.pageX < elementCenter
      el.index()
    else if el.next().length > 0
      el.next().index()
    else
      el.index() + 1
