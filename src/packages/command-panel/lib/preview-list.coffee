$ = require 'jquery'
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
    nextView = selectedView.next().view()

    if selectedView instanceof PathView
      nextView = selectedView.find('.operation:first').view() unless selectedView.hasClass('is-collapsed')
    else
      nextView ?= selectedView.closest('.path').next().view()

    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      nextView.scrollTo()

  selectPreviousOperation: ->
    selectedView = @find('.selected').view()
    previousView = selectedView.prev().view()

    if selectedView instanceof PathView
      if previousView? and not previousView.hasClass('is-collapsed')
        previousView = previousView.find('.operation:last').view()
    else
      previousView ?= selectedView.closest('.path').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      previousView.scrollTo()

  getPathCount: ->
    _.keys(_.groupBy(@operations, (operation) -> operation.getPath())).length

  getOperations: ->
    new Array(@operations...)

  destroyOperations: ->
    operation.destroy() for operation in @getOperations()
    @operations = null

  getSelectedOperation: ->
    @find('.operation.selected').view()?.operation

  scrollTo: (top, bottom) ->
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
