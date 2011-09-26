$ = require 'jquery'

module.exports =
class Pane
  position: null

  html: null

  showing: false

  constructor: (@window) ->

  add: ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = $ "<div>"
    el.addClass "pane " + @position
    el.append @html

    switch @position
      when 'top', 'main'
        verticalDiv.prepend el
      when 'left'
        horizontalDiv.prepend el
      when 'bottom'
        verticalDiv.append el
      when 'right'
        horizontalDiv.append el
      else
        throw "I DON'T KNOW HOW TO DEAL WITH #{@position}"

  toggle: ->
    if @showing
      @html.parent().detach()
    else
      @add this

    @showing = not @showing

  # Override these in your subclass
  initialize: ->
