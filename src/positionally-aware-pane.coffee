_ = require 'underscore-plus'

# Private: Wraps a {Pane} to decorate it with knowledge of its physicial
# location relative to all other {Pane}s.
#
# Intended as a helper for {PaneContainerView}.
module.exports =
class PositionallyAwarePane

  # Creates a {PositionallyAwarePane}.
  #
  # * pane:
  #   The {Pane} that needs to gain some positional awareness.
  # * allPanes:
  #   The collection of all {Pane}s.
  constructor: (@pane, @allPanes) ->

  focusPaneAbove: ->
    @bestChoiceForVerticalNavigation(@panesInAdjecentRowAbove())?.focus()

  focusPaneBelow: ->
    @bestChoiceForVerticalNavigation(@panesInAdjecentRowBelow())?.focus()

  focusPaneOnLeft: ->
    @bestChoiceForHorizontalNavigation(@panesInAdjecentColumnOnLeft())?.focus()

  focusPaneOnRight: ->
    @bestChoiceForHorizontalNavigation(@panesInAdjecentColumnOnRight())?.focus()

  focus: ->
    @pane.focus()

  width: ->
    @pane.width()

  height: ->
    @pane.height()

  xLeft: ->
    @pane.offset().left

  xCenter: ->
    @xLeft() + @width()/2

  xRight: ->
    @xLeft() + @width()

  yTop: ->
    @pane.offset().top

  yCenter: ->
    @yTop() + @height()/2

  yBottom: ->
    @yTop() + @height()

  ### Internal ###

  panesInAdjecentRowAbove: ->
    allPanesAbove = @otherPanes().filter (pane) => @isBelow(pane)
    yBottomValues = _.map allPanesAbove, (pane) -> pane.yBottom()
    maxYBottom = _.max yBottomValues
    panesVerticallyNearest = allPanesAbove.filter (pane) ->
      pane.yBottom() == maxYBottom

  panesInAdjecentRowBelow: ->
    allPanesBelow = @otherPanes().filter (pane) => @isAbove(pane)

    yTopValues = _.map allPanesBelow, (pane) -> pane.yTop()
    minYTop = _.min yTopValues
    panesVerticallyNearest = allPanesBelow.filter (pane) ->
      pane.yTop() == minYTop

  panesInAdjecentColumnOnLeft: ->
    allPanesOnLeft = @otherPanes().filter (pane) => @isRightOf(pane)
    xRightValues = _.map allPanesOnLeft, (pane) -> pane.xRight()
    maxXRight = _.max xRightValues
    panesHorizontallyNearest = allPanesOnLeft.filter (pane) ->
      pane.xRight() == maxXRight

  # Internal
  panesInAdjecentColumnOnRight: ->
    allPanesOnRight = @otherPanes().filter (pane) => @isLeftOf(pane)
    xLeftValues = _.map allPanesOnRight, (pane) -> pane.xLeft()
    minXLeft = _.min xLeftValues
    panesHorizontallyNearest = allPanesOnRight.filter (pane) ->
      pane.xLeft() == minXLeft

  # Determine whether this pane is above the given pane.
  #
  # * otherPane:
  #   The {PositionallyAwarePane} to compare to this pane.
  #
  # Returns true if this pane is above otherPane; otherwise, false.
  isAbove: (otherPane) ->
    otherPaneYTop = otherPane.yTop() + @overlap()
    otherPaneYTop >= @yBottom()

  # Determine whether this pane is below the given pane.
  #
  # * otherPane:
  #   The {PositionallyAwarePane} to compare to this pane.
  #
  # Returns true if this pane is below otherPane; otherwise, false.
  isBelow: (otherPane) ->
    otherPaneYBottom = otherPane.yBottom() - @overlap()
    otherPaneYBottom <= @yTop()

  # Determine whether this pane is to the left of the given pane.
  #
  # * otherPane:
  #   The {PositionallyAwarePane} to compare to this pane.
  #
  # Returns true if this pane is to the left of otherPane; otherwise, false.
  isLeftOf: (otherPane) ->
    otherPaneXLeft = otherPane.xLeft() + @overlap()
    otherPaneXLeft >= @xRight()

  # Determine whether this pane is to the right of the given pane.
  #
  # * otherPane:
  #   The {PositionallyAwarePane} to compare to this pane.
  #
  # Returns true if this pane is to the right of otherPane; otherwise, false.
  isRightOf: (otherPane) ->
    otherPaneXRight = otherPane.xRight() - @overlap()
    otherPaneXRight <= @xLeft()

  # The adjacent column may include several panes. When navigating left or right
  # from this pane, find the pane in the adjacent column that is the most
  # appropriate destination.
  #
  # * panes:
  #   An Array of {PositionallyAwarePane}s in the column adjacent to this pane.
  #
  # Returns a PositionallyAwarePane.
  bestChoiceForHorizontalNavigation: (panes) ->
    _.find panes, (pane) =>
      pane.yTop() <= @yCenter() and @yCenter() <= pane.yBottom()

  # The adjacent row may include several panes. When navigating up or down from
  # this pane, find the pane in the adjacent row that is the most appropriate
  # destination.
  #
  # * panes:
  #   An Array of {PositionallyAwarePane}s in the row adjacent to this pane.
  #
  # Returns a PositionallyAwarePane.
  bestChoiceForVerticalNavigation: (panes) ->
    _.find panes, (pane) =>
      pane.xLeft() <= @xCenter() and @xCenter() <= pane.xRight()

  # In theory, if two panes are side-by-side, then the rightmost x coordinate of
  # the pane on the left should be less than or equal to the leftmost x
  # coordinate of the pane on the right. For example, assume we have two panes:
  #
  #   -----
  #   |1|2|
  #   -----
  #
  # If the rightmost x coordinate of Pane #1 is 400, then the leftmost x
  # coordinate of Pane #2 should be at least 400. In practice, this isn't always
  # true. Sometimes there seems to be a small "overlap" between the two panes.
  # If Pane #1's rightmost x coordinate is 400, then Pane 2's leftmost x
  # coordinate might be 399.2 (for example).
  #
  # A similar issue occurs for the y coordinates.
  #
  # To cope with this issue, this method provides a rough guess as to the
  # amount of overlap between panes.
  #
  # Returns a Number.
  overlap: ->
    2

  # Returns an Array of {PositionallyAwarePane}s for all of the other panes,
  # excluding this pane.
  otherPanes: ->
    _.map @allPanes, (pane) -> new PositionallyAwarePane(pane, @allPanes)

  coordinates: ->
    xLeft:   @xLeft()
    xCenter: @xCenter()
    xRight:  @xRight()
    yTop:    @yTop()
    yCenter: @yCenter()
    yBottom: @yBottom()

  logDebugInfo: ->
    console.log "Coordinates for this pane:"
    console.log @coordinates()

    console.log "Coordinates for other panes:"
    @otherPanes().forEach (pane) -> console.log pane.coordinates()
