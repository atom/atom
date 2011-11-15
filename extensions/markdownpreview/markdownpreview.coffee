fs = require 'fs'

tdoc = require 'docs/tdoc'

Browser = require 'browser'

{Showdown} = require './showdown'
converter  = new Showdown.converter

module.exports =
class Markdownpreview extends Browser
  window.resourceTypes.push this

  running: true

  constructor: ->
    atom.keybinder.load require.resolve "markdownpreview/key-bindings.coffee"

  open: (url) ->
    return false if not url

    if match = url.match /^markdown:(.+)/
      @url = url

      html = '''
        <link rel="stylesheet" href="http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css">
        <style>
          body { padding:10px; }
          code { line-height:16px; }
        </style>

      '''
      html += converter.makeHtml fs.read match[1]

      @show html

      true
