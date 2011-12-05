$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Pane
  paneID: null
  position: null

  constructor: (html) ->
    @paneID = _.uniqueId 'pane-'
    @el = $ "<div id='#{@paneID}'></div>"
    @el.addClass "pane " + @position
    @el.append html

    mousemove = (event) =>
      if @position == "left"
        @el.width event.clientX
      else if @position == "right"
        @el.width window.outerWidth - event.clientX
      else if @position == "bottom"
        @el.height window.outerHeight - event.clientY
      else if @position == "top"
        @el.height event.clientY - @el.offset().top

    mousedown = (event) =>
      maxEdgeDistance = 10
      edgeDistance = switch @position
        when 'top'
          @el.height() - event.clientY + @el.offset().top
        when 'left'
          @el.width() - event.clientX + @el.offset().left
        when 'bottom'
          event.clientY - @el.offset().top
        when 'right'
          event.clientX - @el.offset().left
        else
          throw "pane position for #{this} can't be `#{@position}`"

      if edgeDistance < maxEdgeDistance
        $(document).on 'mouseup', 'body', mouseup
        $(document).on 'mousemove', 'body', mousemove

    mouseup = (event) =>
      $(document).off 'mouseup', 'body', mouseup
      $(document).off 'mousemove', 'body', mousemove

    if @position != 'main'
      id = "##{@paneID}"
      $(document).on 'mousedown', id, mousedown

  add: ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    switch @position
      when 'main'
        # Only one main pane can be visiable.
        $('#main > div').addClass 'hidden'
        $('#main').append @el
      when 'top'
        verticalDiv.prepend @el
      when 'left'
        horizontalDiv.prepend @el
      when 'bottom'
        verticalDiv.append @el
      when 'right'
        horizontalDiv.append @el
      else
        throw "pane position of #{this} can't be `#{@position}`"

  remove: ->
    @el?.remove()

  el: ->
    el = $ "##{@paneID}"
    el[0] and el # Return null if doesn't exist, jquery object if it does

  showing: ->
    @el and not @el.hasClass 'hidden'

  show: ->
    if not @el.parent()[0]
      @add()
    else
      $('#main > div').addClass 'hidden' if @position == 'main'
      @el.removeClass 'hidden'

  hide: ->
    @el.addClass 'hidden'

  toggle: ->
    if @showing()
      @hide()
    else
      @show()
