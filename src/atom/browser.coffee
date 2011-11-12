$ = require 'jquery'

Resource = require 'resource'

module.exports =
class Browser extends Resource
  window.resourceTypes.push this

  path: null
  html: $ "<div id='browser'></div>"
  iframe: ->
    $ "<iframe src='#{@path}' style='width:100%;height:100%'></iframe>"

  open: (path) ->
    return false if not /^https?:/.test path

    @path = path
    @html.html @iframe().bind 'load', (e) =>
      window.setTitle e.target.contentWindow.document.title

    @show()

    true


