fs = require 'fs'
{Document} = require 'ace/document'

module.exports =
class Buffer
  aceDocument: null
  url: null

  constructor: (@url) ->
    text = if @url then fs.read(@url) else ""
    @aceDocument = new Document text

  getText: ->
    @aceDocument.getValue()

