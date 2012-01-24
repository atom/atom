fs = require 'fs'
{Document} = require 'ace/document'

module.exports =
class Buffer
  lines: null

  constructor: (@path) ->
    @url = @path # we want this to be path on master, but let's not break it on a branch
    if @path and fs.exists(@path)
      @setText(fs.read(@path))
    else
      @setText('')

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @lines = text.split('\n')

  getLines: ->
    @lines

  getLine: (n) ->
    @lines[n]

  numLines: ->
    @getLines().length

  save: ->
    if not @path then throw new Error("Tried to save buffer with no url")
    fs.write @path, @getText()

