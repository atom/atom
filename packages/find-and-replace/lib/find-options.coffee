_ = require 'underscore-plus'
{Emitter} = require 'atom'

Params = [
  'findPattern'
  'replacePattern'
  'pathsPattern'
  'useRegex'
  'wholeWord'
  'caseSensitive'
  'inCurrentSelection'
  'leadingContextLineCount'
  'trailingContextLineCount'
]

module.exports =
class FindOptions
  constructor: (state={}) ->
    @emitter = new Emitter

    @findPattern = ''
    @replacePattern = state.replacePattern ? ''
    @pathsPattern = state.pathsPattern ? ''
    @useRegex = state.useRegex ? atom.config.get('find-and-replace.useRegex') ? false
    @caseSensitive = state.caseSensitive ? atom.config.get('find-and-replace.caseSensitive') ? false
    @wholeWord = state.wholeWord ? atom.config.get('find-and-replace.wholeWord') ? false
    @inCurrentSelection = state.inCurrentSelection ? atom.config.get('find-and-replace.inCurrentSelection') ? false
    @leadingContextLineCount = state.leadingContextLineCount ? atom.config.get('find-and-replace.leadingContextLineCount') ? 0
    @trailingContextLineCount = state.trailingContextLineCount ? atom.config.get('find-and-replace.trailingContextLineCount') ? 0

  onDidChange: (callback) ->
    @emitter.on('did-change', callback)

  onDidChangeUseRegex: (callback) ->
    @emitter.on('did-change-useRegex', callback)

  onDidChangeReplacePattern: (callback) ->
    @emitter.on('did-change-replacePattern', callback)

  serialize: ->
    result = {}
    for param in Params
      result[param] = this[param]
    result

  set: (newParams={}) ->
    changedParams = {}
    for key in Params
      if newParams[key]? and newParams[key] isnt this[key]
        changedParams ?= {}
        this[key] = changedParams[key] = newParams[key]

    if Object.keys(changedParams).length
      for param, val of changedParams
        @emitter.emit("did-change-#{param}")
      @emitter.emit('did-change', changedParams)
    return changedParams

  getFindPatternRegex: (forceUnicode = false) ->
    for i in [0..@findPattern.length]
      if @findPattern.charCodeAt(i) > 128
        forceUnicode = true
        break

    flags = 'gm'
    flags += 'i' unless @caseSensitive
    flags += 'u' if forceUnicode

    if @useRegex
      expression = @findPattern
    else
      expression = escapeRegExp(@findPattern)

    expression = "\\b#{expression}\\b" if @wholeWord

    new RegExp(expression, flags)

# This is different from _.escapeRegExp, which escapes dashes. Escaped dashes
# are not allowed outside of character classes in RegExps with the `u` flag.
#
# See atom/find-and-replace#1022
escapeRegExp = (string) ->
  string.replace(/[\/\\^$*+?.()|[\]{}]/g, '\\$&')
