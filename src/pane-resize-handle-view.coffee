{$, View} = require 'atom-space-pen-views'

module.exports =
class PaneResizeHandleView extends View
  @content: ->
    @div class: 'pane-resize-handle'

  initialize: ->
    @handleEvents()

  attached: ->
    @isHorizontal = @parent().hasClass("horizontal")
    @prevPane = @prev()
    @nextPane = @next()

  detached: ->

  handleEvents: ->
    @on 'dblclick', =>
      @resizeToFitContent()
    @on 'mousedown', (e) =>
      @resizeStarted(e)

  resizeToFitContent: ->
    # clear flex-grow css style of both pane
    @prevPane.css('flexGrow', '')
    @nextPane.css('flexGrow', '')

  resizeStarted: (e)->
    e.stopPropagation()
    $(document).on('mousemove', @resizePane)
    $(document).on('mouseup', @resizeStopped)

  calcRatio: (ratio1, ratio2, total) ->
    allRatio = ratio1 + ratio2
    [total * ratio1 / allRatio, total * ratio2 / allRatio]

  getFlexGrow: (element) ->
    parseFloat element.css('flexGrow')

  setFlexGrow: (prevSize, nextSize) ->
    flexGrow = @getFlexGrow(@prevPane) + @getFlexGrow(@nextPane)
    flexGrows = @calcRatio(prevSize, nextSize, flexGrow)
    @prevPane.css('flexGrow', flexGrows[0].toString())
    @nextPane.css('flexGrow', flexGrows[1].toString())

  fixInRange: (val, minValue, maxValue) ->
    Math.min(Math.max(val, minValue), maxValue)

  resizePane: ({pageX, pageY, which}) =>
    return @resizeStopped() unless which is 1

    if @isHorizontal
      totalWidth = @prevPane.outerWidth() + @nextPane.outerWidth()
      #get the left and right width after move the resize view
      leftWidth = @fixInRange(pageX - @prevPane.offset().left, 0, totalWidth)
      rightWidth = totalWidth - leftWidth
      # set the flex grow by the ratio of left width and right width
      # to change pane width
      @setFlexGrow(leftWidth, rightWidth)
    else
      totalHeight = @prevPane.outerHeight() + @nextPane.outerHeight()
      topHeight = @fixInRange(pageY - @prevPane.offset().top, 0, totalHeight)
      bottomHeight = totalHeight - topHeight
      @setFlexGrow(topHeight, bottomHeight)

  resizeStopped: =>
    $(document).off('mousemove', @resizePane)
    $(document).off('mouseup', @resizeStopped)
