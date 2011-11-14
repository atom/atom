$ = require 'jquery'

Resource = require 'resource'

module.exports =
class Browser extends Resource
  window.resourceTypes.push this

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

    if innerHTML
      @pane.find('iframe')[0].contentWindow.document.body.innerHTML = innerHTML
