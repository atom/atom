_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'

TextMateGrammar = require 'text-mate-grammar'


module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @bundles: []

  @loadAll: ->
    for bundlePath in fs.list(require.resolve("bundles"))
      @registerBundle(new TextMateBundle(bundlePath))

  @registerBundle: (bundle)->
    @bundles.push(bundle)

    for grammar in bundle.grammars
      for fileType in grammar.fileTypes
        @grammarsByFileType[fileType] = grammar

  @grammarForFileName: (fileName) ->
    extension = fs.extension(fileName)[1...]
    @grammarsByFileType[extension] or @grammarsByFileType["txt"]

  grammars: null

  constructor: (bundlePath) ->
    @grammars = []
    syntaxesPath = fs.join(bundlePath, "Syntaxes")
    if fs.exists(syntaxesPath)
      for syntaxPath in fs.list(syntaxesPath)
        @grammars.push TextMateGrammar.loadFromPath(syntaxPath)


