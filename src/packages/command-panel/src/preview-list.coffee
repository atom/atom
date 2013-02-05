$ = require 'jquery'
{$$$} = require 'space-pen'
ScrollView = require 'scroll-view'
_ = require 'underscore'
fs = require 'fs'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list', tabindex: -1, ->

  selectedOperationIndex: 0
  operations: null

  initialize: (@rootView) ->
    super
    @on 'core:move-down', => @selectNextOperation(); false
    @on 'core:move-up', => @selectPreviousOperation(); false
    @on 'core:confirm', => @executeSelectedOperation()

    @on 'mousedown', 'li.operation', (e) =>
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
      operation.index = index for operation, index in operations
      operationsByPath = _.groupBy(operations, (operation) -> operation.getPath())
      for path, ops of operationsByPath
        classes = ['path']
        classes.push('readme') if fs.isReadme(path)
        @li class: classes.join(' '), =>
          @span path
          @span "(#{ops.length})", class: 'path-match-number'
        for operation in ops
          {prefix, suffix, match, range} = operation.preview()
          @li 'data-index': operation.index, class: 'operation', =>
            @span range.start.row + 1, class: 'line-number'
            @span class: 'preview', =>
              @span prefix
              @span match, class: 'match'
              @span suffix

    @setSelectedOperationIndex(0)
    @show()
    @setLineNumberWidth()

  setLineNumberWidth: ->
    lineNumbers = @find('.line-number')
    maxWidth = 0
    lineNumbers.each (index, element) ->
      maxWidth = Math.max($(element).outerWidth(), maxWidth)
    lineNumbers.width(maxWidth)

  selectNextOperation: ->
    @setSelectedOperationIndex(@selectedOperationIndex + 1)

  selectPreviousOperation: ->
    @setSelectedOperationIndex(@selectedOperationIndex - 1)

  setSelectedOperationIndex: (index, scrollToOperation=true) ->
    index = Math.max(0, index)
    index = Math.min(@operations.length - 1, index)
    @children(".selected").removeClass('selected')
    element = @children("li.operation:eq(#{index})")
    element.addClass('selected')

    if scrollToOperation
      if index is 0
        @scrollToTop()
      else
        @scrollToElement(element)

    @selectedOperationIndex = index

  executeSelectedOperation: ->
    operation = @getSelectedOperation()
    editSession = @rootView.open(operation.getPath())
    bufferRange = operation.execute(editSession)
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange
    @focus()
    false

  getPathCount: ->
    _.keys(_.groupBy(@operations, (operation) -> operation.getPath())).length

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

  scrollToBottom: ->
    super()

    @setSelectedOperationIndex(Infinity, false)

  scrollToTop: ->
    super()

    @setSelectedOperationIndex(0, false)
