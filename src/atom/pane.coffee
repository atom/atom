$ = require 'jquery'

module.exports =
class Pane
  position: null

  html: null

  add: ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    @pane = $ "<div>"
    @pane.addClass "pane " + @position
    @pane.append @html

    switch @position
      when 'main'
        # There can be multiple 'main' panes, but only one can be active
        # at at time. ICK.
        $('#main-container').children().css 'display', 'none !important'
        $('#main-container').append @pane
      when 'top'
        verticalDiv.prepend @pane
      when 'left'
        horizontalDiv.prepend @pane
      when 'bottom'
        verticalDiv.append @pane
      when 'right'
        horizontalDiv.append @pane
      else
        throw "pane position of #{this} can't be `#{@position}`"

  showing: ->
    @pane and not @pane.css('display').match /none/

  show: ->
    if @position == 'main'
      $('#main-container').children().css 'display', 'none !important'

    if not @pane
      @add()
    else
      @pane.css 'display', '-webkit-box !important'

  hide: ->
    @pane.css 'display', 'none !important'

  toggle: ->
    if @showing()
      @hide()
    else
      @show()
