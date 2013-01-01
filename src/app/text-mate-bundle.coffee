_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'
$ = require 'jquery'

TextMateGrammar = require 'text-mate-grammar'

module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @grammarsByScopeName: {}
  @grammars: []

  @load: (name) ->
    bundle = new TextMateBundle(require.resolve(name))
    syntax.addGrammar(grammar) for grammar in bundle.grammars
    bundle

  grammars: null

  constructor: (@path) ->

  getSyntaxesPath: ->
    fs.join(@path, "Syntaxes")
