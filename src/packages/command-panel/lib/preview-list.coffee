$ = require 'jquery'
{$$$} = require 'space-pen'
ScrollView = require 'scroll-view'
_ = require 'underscore'
fs = require 'fs'
PathView = require './path-view'
OperationView = require './operation-view'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list', tabindex: -1

  operations: null

  initialize: ->
    super

    @on 'core:move-down', => @selectNextOperation(); false
    @on 'core:move-up', => @selectPreviousOperation(); false

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
      @append new PathView({path, operations, previewList: this})

    @show()
    @find('.operation:first').addClass('selected')
    @setLineNumberWidth()

  setLineNumberWidth: ->
    lineNumbers = @find('.line-number')
    maxWidth = 0
    lineNumbers.each (index, element) ->
      maxWidth = Math.max($(element).outerWidth(), maxWidth)
    lineNumbers.width(maxWidth)

  selectNextOperation: ->
    selectedView = @find('.selected').view()

    if selectedView instanceof PathView
      if selectedView.hasClass('is-collapsed')
        nextView = selectedView.next().view()
      else
        nextView = selectedView.find('.operation:first')
    else
      nextView = selectedView.next().view() ? selectedView.closest('.path').next().view()
    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      @scrollToElement(nextView)

  selectPreviousOperation: ->
    selectedView = @find('.selected').view()

    if selectedView instanceof PathView
      previousView = selectedView.prev()
      previousView = previousView.find('.operation:last').view() unless previousView.hasClass('is-collapsed')
    else
      previousView = selectedView.prev().view() ? selectedView.closest('.path').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      @scrollToElement(previousView)

  getPathCount: ->
    _.keys(_.groupBy(@operations, (operation) -> operation.getPath())).length

  getOperations: ->
    new Array(@operations...)

  destroyOperations: ->
    operation.destroy() for operation in @getOperations()
    @operations = null

  getSelectedOperation: ->
    @find('.operation.selected').view()?.operation

  scrollToElement: (element) ->
    top = @scrollTop() + element.offset().top - @offset().top
    bottom = top + element.outerHeight()

    @scrollBottom(bottom) if bottom > @scrollBottom()
    @scrollTop(top) if top < @scrollTop()

  scrollToBottom: ->
    super()

    @find('.selected').removeClass('selected')
    lastPath = @find('.path:last')
    if lastPath.hasClass('is-collapsed')
      lastPath.addClass('selected')
    else
      lastPath.find('.operation:last').addClass('selected')

  scrollToTop: ->
    super()

    @find('.selected').removeClass('selected')
    @find('.path:first').addClass('selected')
