{View} = require 'space-pen'
$ = require 'jquery'

module.exports =
class SortableList extends View
  @viewClass: -> 'sortable-list'

  initialize: ->
    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend',   '.sortable', @onDragEnd
    @on 'dragover',  '.sortable', @onDragOver
    @on 'dragenter', '.sortable', @onDragEnter
    @on 'dragleave', '.sortable', @onDragLeave
    @on 'drop',      '.sortable', @onDrop

  onDragStart: (event) =>
    return false if !@shouldAllowDrag()

    el = @getSortableElement(event)
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'sortable-index', el.index()

  onDragEnd: (event) =>
    @getSortableElement(event).removeClass 'is-dragging'

  onDragEnter: (event) =>
    event.preventDefault()

  onDragOver: (event) =>
    event.preventDefault()
    @getSortableElement(event).addClass 'is-drop-target'

  onDragLeave: (event) =>
    @getSortableElement(event).removeClass 'is-drop-target'

  onDrop: (event) =>
    return false if !@shouldAllowDrop()
    event.stopPropagation()
    @find('.is-drop-target').removeClass 'is-drop-target'

  shouldAllowDrag: ->
    true

  shouldAllowDrop: ->
    true

  getDroppedElement: (event) ->
    idx = event.originalEvent.dataTransfer.getData 'sortable-index'
    @find ".sortable:eq(#{idx})"

  getSortableElement: (event) ->
    el = $(event.target)
    if !el.hasClass('sortable') then el.closest('.sortable') else el