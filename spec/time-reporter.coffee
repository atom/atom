_ = require 'underscore-plus'

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
    return unless window.timedSuites.length > 0

    log ?= (line) -> console.log(line)
    log "Longest running suites:"
    suites = _.map(window.timedSuites, (key, value) -> [value, key])
    for suite in _.sortBy(suites, (suite) -> -suite[1])[0...number]
      time = Math.round(suite[1] / 100) / 10
      log "  #{suite[0]} (#{time}s)"
    undefined

  logLongestSpecs: (number=10, log) ->
    return unless window.timedSpecs.length > 0

    log ?= (line) -> console.log(line)
    log "Longest running specs:"
    for spec in _.sortBy(window.timedSpecs, (spec) -> -spec.time)[0...number]
      time = Math.round(spec.time / 100) / 10
      log "#{spec.description} (#{time}s)"
    undefined

  reportSpecStarting: (spec) ->
    stack = [spec.description]
    suite = spec.suite
    while suite
      stack.unshift suite.description
      @suite = suite.description
      suite = suite.parentSuite

    reducer = (memo, description, index) ->
      if index is 0
        "#{description}"
      else
        "#{memo}\n#{_.multiplyString('  ', index)}#{description}"
    @description = _.reduce(stack, reducer, '')
    @time = Date.now()

  reportSpecResults: (spec) ->
    return unless @time? and @description?

    duration = Date.now() - @time

    if duration > 0
      window.timedSpecs.push
        description: @description
        time: duration
        fullName: spec.getFullName()

      if timedSuites[@suite]
        window.timedSuites[@suite] += duration
      else
        window.timedSuites[@suite] = duration

    @time = null
    @description = null
