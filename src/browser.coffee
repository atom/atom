$ = require 'jquery'

module.exports =
class Browser
  constructor: (@path) ->
    $('.main.pane').append @html().hide()
  on: ->
  html: ->
    $ "<iframe src='#{@path}' style='width:100%;height:100%'></iframe>"
  show: ->
    $(".main iframe[src='#{@path}']").show()
  hide: ->
    $(".main iframe[src='#{@path}']").hide()