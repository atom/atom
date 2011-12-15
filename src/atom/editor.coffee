Buffer = require 'buffer'

module.exports =
class Editor
  buffer: null

  constructor: (url) ->
    @buffer = new Buffer(url)

