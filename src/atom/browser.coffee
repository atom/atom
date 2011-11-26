$ = require 'jquery'

Resource = require 'resource'

# Events:
#   browser:close (browser) -> Called when a browser is closed.
module.exports =
class Browser extends Resource
  window.resourceTypes.push this

  open: (url) ->
    return false if not /^https?:/.test url

    @url = url
    @show()

    true

  close: ->
    atom.trigger 'browser:close', this
    super

  # innerHTML - Optional String to set as iframe's content.
  show: (innerHTML=null) ->
    if not @pane
      @add innerHTML
    else
      super

  # innerHTML - Optional String to set as iframe's content.
  add: (innerHTML=null) ->
    style = "width:100%;height:100%;background-color:#fff;border:none"
    @html = "<iframe src='#{@url}' style='#{style}'></iframe>"

    super

    iframe = @pane.find('iframe')[0]

    if innerHTML
      iframe.contentWindow.document.body.innerHTML = innerHTML

    if @title
      window.setTitle @title
    else
      window.setTitle iframe.contentWindow.document.title
      $(iframe).bind 'load', (e) =>
        window.setTitle e.target.contentWindow.document.title