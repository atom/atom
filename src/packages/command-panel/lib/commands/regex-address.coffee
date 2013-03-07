Address = require './address'
Range = require 'range'
_ = require 'underscore'

module.exports =
class RegexAddress extends Address
  regex: null
  reverse: null

  searchOptions = 
    regex: true
    caseSensitive: false

  constructor: (@pattern, isReversed) ->
    flags = ""
    pattern = pattern.source if pattern.source
    
    @isReversed = isReversed

    if !searchOptions.regex
      pattern = @escape(pattern)
    if !searchOptions.caseSensitive
      flags += "i"
    if searchOptions.wholeWord
      pattern = "\\b#{pattern}\\b"

    @regex = new RegExp(pattern, flags)

  getRange: (buffer, range) ->
    rangeBefore = new Range([0, 0], range.start)
    rangeAfter = new Range(range.end, buffer.getEofPosition())

    rangeToSearch = if @isReversed then rangeBefore else rangeAfter

    rangeToReturn = null
    scanMethodName = if @isReversed then "backwardsScanInRange" else "scanInRange"
    buffer[scanMethodName] @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    if not rangeToReturn
      rangeToSearch = if @isReversed then rangeAfter else rangeBefore
      buffer[scanMethodName] @regex, rangeToSearch, (match, range) ->
        rangeToReturn = range

    if not rangeToReturn
      flags = ""
      flags += "i" if @regex.ignoreCase
      flags += "g" if @regex.global
      flags += "m" if @regex.multiline
      @errorMessage = "Pattern not found /#{@regex.source}/#{flags}"

    rangeToReturn or range

  isRelative: -> true

  reverse: ->
    new RegexAddress(@regex, !@isReversed)

  @setOptions: (options) ->
    searchOptions = _.extend(searchOptions, options)

  escape: (pattern) ->
    pattern.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
