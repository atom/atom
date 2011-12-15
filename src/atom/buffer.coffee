fs = require 'fs'

module.exports =
class Buffer
  text: null
  url: null

  constructor: (@url) ->
    @text = fs.read @url
