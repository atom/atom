fs = require 'fs'
{Document} = require 'ace/document'

module.exports =
class Buffer
  aceDocument: null
  url: null

  constructor: (@url) ->
    @aceDocument = new Document fs.read(@url)

  getText: ->
    @aceDocument.getValue()

