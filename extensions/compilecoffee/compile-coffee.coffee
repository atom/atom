fs = require 'fs'

Editor = require 'editor'
Extension = require 'extension'

{CoffeeScript} = require 'coffee-script'

module.exports =
class CompileCoffee extends Editor
  window.resourceTypes.push this

  running: true

  open: (url) ->
    return false if not url

    if match = url.match /^compilecoffee:\/\/(.+)/
      @url = url

      @show CoffeeScript.compile fs.read match[1]
      @setModeForURL @url.replace '.coffee', '.js'

      true
