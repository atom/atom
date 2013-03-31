$ = require 'jquery'
ScrollView = require 'scroll-view'
_ = require 'underscore'
PathView = require './path-view'
OperationView = require './operation-view'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list', tabindex: -1

  operations: null
  viewsForPath: null
  pixelOverdraw: 100
  lastRenderedOperationIndex: null

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
    @lastRenderedOperationIndex = 0
    @empty()
    @viewsForPath = {}

    @show()
    @renderOperations()

    @find('.operation:first').addClass('selected')

  populateSingle: (operation) ->
    @viewsForPath ||= {}

    @lastRenderedOperationIndex ||= 0
    @renderOperation(operation)

    @find('.operation:first').addClass('selected')

  renderOperations: ({renderAll}={}) ->
    renderAll ?= false
    startingScrollHeight = @prop('scrollHeight')
    for operation in @operations[@lastRenderedOperationIndex..]
      pathView = @pathViewForPath(operation.getPath())
      pathView.addOperation(operation)
      @lastRenderedOperationIndex++
      break if not renderAll and @prop('scrollHeight') >= startingScrollHeight + @pixelOverdraw and @prop('scrollHeight') > @height() + @pixelOverdraw

  renderOperation: (operation) ->
    startingScrollHeight = @prop('scrollHeight')
    pathView = @pathViewForPath(operation.getPath())
    pathView.addOperation(operation)
    @lastRenderedOperationIndex++
 
  pathViewForPath: (path) ->
    pathView = @viewsForPath[path]
    if not pathView
      pathView = new PathView({path: path, previewList: this})
      @viewsForPath[path] = pathView
      @append(pathView)
    pathView

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

  getPathCount: (operations=@operations)->
    _.keys(_.groupBy(operations, (operation) -> operation.getPath())).length

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
