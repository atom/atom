{View} = require 'space-pen'
$ = require 'jquery'

module.exports =
class SortableView extends View
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
    el = @sortableElement(event)
    el.removeClass 'is-dragging'

  onDragEnter: (event) =>
    event.preventDefault()

  onDragOver: (event) =>
    event.preventDefault()

  onDragLeave: (event) =>
    el = @sortableElement(event)
    el.removeClass 'is-drop-target'

  onDrop: (event) =>
    event.stopPropagation()
    el = @sortableElement(event)
    idx = event.originalEvent.dataTransfer.getData('index')
    dropped = el.parent().find(".sortable:eq(#{idx})")
    dropped.remove()
    dropped.insertBefore(el)

  sortableElement: (event) ->
    el = $(event.target)
    if !el.hasClass('sortable') then el.closest('.sortable') else el

