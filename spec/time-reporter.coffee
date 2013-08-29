_ = require 'underscore'

module.exports =
class TimeReporter extends jasmine.Reporter

  constructor: ->
    window.timedSpecs = []
    window.timedSuites = {}

    window.logLongestSpec = => @logLongestSpecs(1)
    window.logLongestSpecs = (number) => @logLongestSpecs(number)
    window.logLongestSuite = => @logLongestSuites(1)
    window.logLongestSuites = (number) => @logLongestSuites(number)

  logLongestSuites: (number=10, log) ->
    log ?= (line) -> console.log(line)
    log "Longest running suites:"
    suites = _.map(window.timedSuites, (key, value) -> [value, key])
    for suite in _.sortBy(suites, (suite) => -suite[1])[0...number]
      log "  #{suite[0]} (#{suite[1]}ms)"

  logLongestSpecs: (number=10, log) ->
    log ?= (line) -> console.log(line)
    log "Longest running specs:"
    for spec in _.sortBy(window.timedSpecs, (spec) -> -spec.time)[0...number]
      log spec.description

  reportSpecStarting: (spec) ->
    @stack = [spec.description]
    suite = spec.suite
    while suite
      @stack.unshift suite.description
      @suite = suite.description
      suite = suite.parentSuite

    @time = new Date().getTime()

  reportSpecResults: (spec) ->
    return unless @time? and @stack?

    duration = new Date().getTime() - @time
    reducer = (memo, description, index) ->
      if index is 0
        "#{description} (#{duration}ms)\n"
      else
        "#{memo}#{_.multiplyString('  ', index)}#{description}\n"
    description = _.reduce(@stack, reducer, '')

    window.timedSpecs.push
      description: description
      time: duration
    if timedSuites[@suite]
      window.timedSuites[@suite] += duration
    else
      window.timedSuites[@suite] = duration

    @time = null
    @stack = null
