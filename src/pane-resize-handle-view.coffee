{$, View} = require 'atom-space-pen-views'

module.exports =
class PaneResizeHandleView extends View
  @content: ->
    @div class: 'pane-resize-handle'

  initialize: ->
    @handleEvents()

  attached: ->
    @isHorizontal = @parent().hasClass("horizontal")

  detached: ->

  handleEvents: ->
    @on 'dblclick', =>
      @resizeToFitContent()
    @on 'mousedown', (e) =>
      @resizeStarted(e)

  resizeToFitContent: ->
    # clear flex-grow css style of both pane
    @prev().css('flexGrow', '')
    @next().css('flexGrow', '')

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
    flexGrow = @getFlexGrow(@prev()) + @getFlexGrow(@next())
    flexGrows = @calcRatio(prevSize, nextSize, flexGrow)
    @prev().css('flexGrow', flexGrows[0].toString())
    @next().css('flexGrow', flexGrows[1].toString())

  fixInRange: (val, minValue, maxValue) ->
    Math.min(Math.max(val, minValue), maxValue)

  resizePane: ({pageX, pageY, which}) =>
    return @resizeStopped() unless which is 1

    if @isHorizontal
      totalWidth = @prev().outerWidth() + @next().outerWidth()
      #get the left and right width after move the resize view
      leftWidth = @fixInRange(pageX - @prev().offset().left, 0, totalWidth)
      rightWidth = totalWidth - leftWidth
      # set the flex grow by the ratio of left width and right width
      # to change pane width
      @setFlexGrow(leftWidth, rightWidth)
    else
      totalHeight = @prev().outerHeight() + @next().outerHeight()
      topHeight = @fixInRange(pageY - @prev().offset().top, 0, totalHeight)
      bottomHeight = totalHeight - topHeight
      @setFlexGrow(topHeight, bottomHeight)

  resizeStopped: =>
    $(document).off('mousemove', @resizePane)
    $(document).off('mouseup', @resizeStopped)
