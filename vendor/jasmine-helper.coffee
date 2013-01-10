module.exports.runSpecSuite = (specSuite, logErrors=true) ->
  {$$} = require 'space-pen'
  nakedLoad 'jasmine'
  nakedLoad 'jasmine-atom-reporter'
  nakedLoad 'jasmine-console-reporter'
  nakedLoad 'jasmine-focused'

  $ = require 'jquery'
  _ = require 'underscore'

  $('body').append $$ ->
    @div id: 'jasmine-content'

  reporter = if atom.exitWhenDone
    new jasmine.ConsoleReporter(document, logErrors)
  else
    new jasmine.AtomReporter(document)

  require specSuite
  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)

  class TimeReporter  extends jasmine.Reporter

    timedSpecs: []

    reportSpecStarting: (spec) ->
      stack = [spec.description]
      suite = spec.suite
      while suite
        stack.unshift suite.description
        suite = suite.parentSuite

      @time = new Date().getTime()
      @description = stack.join(' -> ')

    reportSpecResults: ->
      return unless @time? and @description?
      @timedSpecs.push
        description: @description
        time: new Date().getTime() - @time
      @time = null
      @description = null

    reportRunnerResults: ->
      console.log '10 longest running specs:'
      for spec in _.sortBy(@timedSpecs, (spec) -> -spec.time)[0...10]
        console.log "#{spec.time}ms"
        console.log spec.description

  jasmineEnv.addReporter(new TimeReporter())
  jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)
  jasmineEnv.execute()
