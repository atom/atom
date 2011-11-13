$ = require 'jquery'

Resource = require 'resource'

module.exports =
class Browser extends Resource
  window.resourceTypes.push this

  url: null

  html: $ "<div id='browser'></div>"

  iframe: ->
    $ "<iframe src='#{@url}' style='width:100%;height:100%'></iframe>"

  open: (url) ->
    return false if not /^https?:/.test url

    @url = url
    @html.html @iframe().bind 'load', (e) =>
      window.setTitle e.target.contentWindow.document.title

    @show()

    true


