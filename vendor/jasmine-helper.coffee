module.exports.runSpecSuite = (specSuite, logErrors=true) ->
  {$$} = require 'space-pen'
  nakedLoad 'jasmine'
  nakedLoad 'jasmine-atom-reporter'
  nakedLoad 'jasmine-console-reporter'
  nakedLoad 'jasmine-focused'

  $ = require 'jquery'
  TimeReporter = require 'time-reporter'

  reporter = if atom.exitWhenDone
    new jasmine.ConsoleReporter(document, logErrors)
  else
    new jasmine.AtomReporter(document)

  require specSuite
  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)

  jasmineEnv.addReporter(new TimeReporter())
  jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)

  $('body').append $$ ->
    @div id: 'jasmine-content'

  jasmineEnv.execute()
