_ = require 'underscore'

module.exports =
class TimeReporter  extends jasmine.Reporter

  constructor: ->
    window.timedSpecs = []
    window.timedSuites = {}

    window.logLongestSpec = -> window.logLongestSpecs(1)

    window.logLongestSpecs = (number=10) =>
      console.log "#{number} longest running specs:"
      for spec in _.sortBy(window.timedSpecs, (spec) -> -spec.time)[0...number]
        console.log "#{spec.time}ms"
        console.log spec.description

    window.logLongestSuite = -> window.logLongestSuites(1)

    window.logLongestSuites = (number=10) =>
      console.log "#{number} longest running suites:"
      suites = _.map(window.timedSuites, (key, value) -> [value, key])
      for suite in _.sortBy(suites, (suite) => -suite[1])[0...number]
        console.log suite[0], suite[1]

  reportSpecStarting: (spec) ->
    stack = [spec.description]
    suite = spec.suite
    while suite
      stack.unshift suite.description
      @suite = suite.description
      suite = suite.parentSuite

    @time = new Date().getTime()
    reducer = (memo, description, index) ->
      "#{memo}#{_.multiplyString(' ', index)}#{description}\n"
    @description = _.reduce(stack, reducer, "")

  reportSpecResults: (spec) ->
    return unless @time? and @description?

    duration = new Date().getTime() - @time
    window.timedSpecs.push
      description: @description
      time: duration
      name: spec.getFullName()
    if timedSuites[@suite]
      window.timedSuites[@suite] += duration
    else
      window.timedSuites[@suite] = duration
    @time = null
    @description = null
