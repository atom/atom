$ = require 'jquery'
{$$$} = require 'space-pen'
ScrollView = require 'app/scroll-view'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list', tabindex: -1, ->

  selectedOperationIndex: 0
  operations: null

  initialize: (@rootView) ->
    super
    @on 'core:move-down', => @selectNextOperation()
    @on 'core:move-up', => @selectPreviousOperation()
    @on 'core:confirm', => @executeSelectedOperation()

    @on 'mousedown', 'li', (e) =>
      @setSelectedOperationIndex(parseInt($(e.target).closest('li').data('index')))
      @executeSelectedOperation()

  destroy: ->
    @destroyOperations() if @operations

  hasOperations: -> @operations?

  populate: (operations) ->
    @destroyOperations() if @operations
    @operations = operations
    @empty()
    @html $$$ ->
      for operation, index in operations
        {prefix, suffix, match} = operation.preview()
        @li 'data-index': index, =>
          @span operation.getPath(), outlet: "path", class: "path"
          @span outlet: "preview", class: "preview", =>
            @span prefix
            @span match, class: 'match'
            @span suffix

    @setSelectedOperationIndex(0)
    @show()

  selectNextOperation: ->
    @setSelectedOperationIndex(@selectedOperationIndex + 1)

  selectPreviousOperation: ->
    @setSelectedOperationIndex(@selectedOperationIndex - 1)

  setSelectedOperationIndex: (index) ->
    index = Math.max(0, index)
    index = Math.min(@operations.length - 1, index)
    @children(".selected").removeClass('selected')
    element = @children("li:eq(#{index})")
    element.addClass('selected')
    @scrollToElement(element)
    @selectedOperationIndex = index

  executeSelectedOperation: ->
    operation = @getSelectedOperation()
    editSession = @rootView.open(operation.getPath())
    bufferRange = operation.execute(editSession)
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange
    @rootView.focus()
    false

  getOperations: ->
    new Array(@operations...)

  destroyOperations: ->
    operation.destroy() for operation in @getOperations()
    @operations = null

  getSelectedOperation: ->
    @operations[@selectedOperationIndex]

  scrollToElement: (element) ->
    top = @scrollTop() + element.position().top
    bottom = top + element.outerHeight()

    if bottom > @scrollBottom()
      @scrollBottom(bottom)
    if top < @scrollTop()
      @scrollTop(top)
