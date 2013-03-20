PEG = require('pegjs')
fs = require('fs')

module.exports =
class PEGjsGrammar
  constructor: (@name, @grammarFile, @fileTypes, @scopeName) ->
    @parser = PEG.buildParser fs.read(@grammarFile),
                                cache:    false
                                output:   "parser"
                                optimize: "speed"
                                plugins:  []
    @cache  = {}
