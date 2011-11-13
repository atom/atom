$ = require 'jquery'

Resource = require 'resource'

module.exports =
class Browser extends Resource
  window.resourceTypes.push this

  url: null

  open: (url) ->
    return false if not /^https?:/.test url

    @url = url

    @html = """
      <iframe src='#{@url}' style='width:100%;height:100%'></iframe>
    """

    @show()

    true


