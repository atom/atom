fs = require 'fs'

tdoc = require 'docs/tdoc'

Browser = require 'browser'

module.exports =
class Docs extends Browser
  window.resourceTypes.push this

  running: true

  constructor: ->
    atom.keybinder.load require.resolve "docs/key-bindings.coffee"

  open: (url) ->
    return false if not url

    if match = url.match /^docs:\/\/(.+)/
      @url = url
      code = fs.read match[1]
      @show tdoc.html code
      true
