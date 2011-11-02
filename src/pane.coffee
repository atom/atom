$ = require 'jquery'

module.exports =
class Pane
  position: null

  html: null

  showing: false

  add: ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = $ "<div>"
    el.addClass "pane " + @position
    el.append @html

    switch @position
      when 'main'
        $('.main').replaceWith el
      when 'top'
        verticalDiv.prepend el
      when 'left'
        horizontalDiv.prepend el
      when 'bottom'
        verticalDiv.append el
      when 'right'
        horizontalDiv.append el
      else
        throw "I DON'T KNOW HOW TO DEAL WITH #{@position}"

  show: ->
    @add this
    @showing = true

  hide: ->
    @html.parent().detach()
    @showing = false

  toggle: ->
    if @showing
      @hide()
    else
      @show()
