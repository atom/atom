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
    el = @sortableElement(event)
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'index', el.index()

  onDragEnd: (event) =>
    @sortableElement(event).removeClass 'is-dragging'

  onDragEnter: (event) =>
    event.preventDefault()

  onDragOver: (event) =>
    event.preventDefault()
    @sortableElement(event).addClass 'is-drop-target'

  onDragLeave: (event) =>
    @sortableElement(event).removeClass 'is-drop-target'

  onDrop: (event) =>
    event.stopPropagation()
    el = @sortableElement(event)
    dropped = @getDroppedElement(event)
    dropped.remove()
    dropped.insertBefore(el)

    @find('.is-drop-target').removeClass 'is-drop-target'

  getDroppedElement: (event) ->
    idx = event.originalEvent.dataTransfer.getData('index')
    @find ".sortable:eq(#{idx})"

  sortableElement: (event) ->
    el = $(event.target)
    if !el.hasClass('sortable') then el.closest('.sortable') else el