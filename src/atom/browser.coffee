$ = require 'jquery'

Resource = require 'resource'

module.exports =
class Browser extends Resource
  atom.router.add this

  url: null

  open: (url) ->
    return false if not /^https?:/.test url

    @url = url
    @show()

    true

  # innerHTML - Optional String to set as iframe's content.
  show: (innerHTML=null) ->
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