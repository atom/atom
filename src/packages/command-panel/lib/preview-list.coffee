$ = require 'jquery'
{$$$} = require 'space-pen'
ScrollView = require 'scroll-view'
_ = require 'underscore'
fs = require 'fs'
PathView = require './path-view'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list', tabindex: -1

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

    @command 'command-panel:collapse-all', => @collapseAllPaths()
    @command 'command-panel:expand-all', => @expandAllPaths()

  expandAllPaths: ->
    @children().each (index, element) -> $(element).view().expand()

  collapseAllPaths: ->
    @children().each (index, element) -> $(element).view().collapse()

  destroy: ->
    @destroyOperations() if @operations

  hasOperations: -> @operations?

  populate: (operations) ->
    @destroyOperations() if @operations
    @operations = operations
    @empty()

    operation.index = index for operation, index in operations
    operationsByPath = _.groupBy(operations, (operation) -> operation.getPath())
    for path, operations of operationsByPath
      @append new PathView({path, operations})

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
    @find('li.selected').removeClass('selected')
    element = @find("ul.matches li.operation:eq(#{index})")
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
    top = @scrollTop() + element.offset().top - @offset().top
    bottom = top + element.outerHeight()

    @scrollBottom(bottom) if bottom > @scrollBottom()
    @scrollTop(top) if top < @scrollTop()

  scrollToBottom: ->
    super()

    @setSelectedOperationIndex(Infinity, false)

  scrollToTop: ->
    super()

    @setSelectedOperationIndex(0, false)
