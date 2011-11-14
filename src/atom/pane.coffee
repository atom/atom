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
        $('#main > div').addClass 'hidden'
        $('#main').append @pane
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
    @pane and not @pane.hasClass 'hidden'

  show: ->
    if not @pane
      @add()
    else
      $('#main > div').addClass 'hidden' if @position == 'main'
      @pane.removeClass 'hidden'

  hide: ->
    @pane.addClass 'hidden'

  toggle: ->
    if @showing()
      @hide()
    else
      @show()
