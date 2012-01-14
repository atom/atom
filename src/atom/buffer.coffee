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

    extension = if @url then @url.split('/').pop().split('.').pop() else null
    modeName = switch extension
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'

      else 'text'

    @mode = new (require("ace/mode/#{modeName}").Mode)
    @mode.name = modeName
    @mode

  save: ->
    if not @url then throw new Error("Tried to save buffer with no url")
    fs.write @url, @getText()

  getLine: (row) ->
    @aceDocument.getLine(row)

