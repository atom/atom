$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Pane
  paneID: null
  position: null

  constructor: (html) ->
    @paneID = _.uniqueId 'pane-'
    @el = $ "<div id=#{@paneID}>"
    @el.addClass "pane " + @position
    @el.append html

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
