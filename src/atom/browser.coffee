$ = require 'jquery'

Document = require 'document'

module.exports =
class Browser extends Document
  window.resourceTypes.push [this, (url) -> /^https?:/.test url]

  path: null
  html: $ "<div id='browser'></div>"
  iframe: ->
    $ "<iframe src='#{@path}' style='width:100%;height:100%'></iframe>"

  open: (path) ->
    @path = path
    @html.html @iframe().bind 'load', (e) =>
      window.setTitle e.target.contentWindow.document.title

    @show()

    true


