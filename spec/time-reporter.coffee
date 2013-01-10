_ = require 'underscore'

module.exports =
class TimeReporter  extends jasmine.Reporter

  timedSpecs: []

  constructor: ->
    window.logLongestSpec = -> window.logLongestSpecs(1)
    window.logLongestSpecs = (number=10) =>
      console.log "#{number} longest running specs:"
      for spec in _.sortBy(@timedSpecs, (spec) -> -spec.time)[0...number]
        console.log "#{spec.time}ms"
        console.log spec.description

  reportSpecStarting: (spec) ->
    stack = [spec.description]
    suite = spec.suite
    while suite
      stack.unshift suite.description
      suite = suite.parentSuite

    @time = new Date().getTime()
    reducer = (memo, description, index) ->
      "#{memo}#{_.multiplyString(' ', index)}#{description}\n"
    @description = _.reduce(stack, reducer, "")

  reportSpecResults: ->
    return unless @time? and @description?
    @timedSpecs.push
      description: @description
      time: new Date().getTime() - @time
    @time = null
    @description = null
