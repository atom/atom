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

  getMode: ->
    return @mode if @mode

    extension = @url.split('/').pop().split('.').pop()
    modeName = switch extension
      when "js" then "javascript"
      else "text"

    @mode = new (require("ace/mode/#{modeName}").Mode)
    @mode.name = modeName
    @mode

  save: ->
    if not @url then throw new Error("Tried to save buffer with no url")
    fs.write @url, @getText()
