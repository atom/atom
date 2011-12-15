fs = require 'fs'
{Document} = require 'ace/document'

module.exports =
class Buffer
  aceDocument: null
  url: null

  constructor: (@url) ->
    text = if @url and fs.exists(@url)
      fs.read(@url)
    else
      ""
    @aceDocument = new Document text

  getText: ->
    @aceDocument.getValue()

  setText: (text) ->
    @aceDocument.setValue text

  save: ->
    if not @url then throw new Error("Tried to save buffer with no url")
    fs.write @url, @getText()
