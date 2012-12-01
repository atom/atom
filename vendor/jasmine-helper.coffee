_ = require 'underscore'

module.exports.runSpecSuite = (specSuite, logErrors=true) ->
  {$$} = require 'space-pen'
  _.defaults(global, require 'jasmine')

  require 'jasmine-atom-reporter'
  require 'jasmine-console-reporter'
  require 'jasmine-focused'

  $ = require 'jquery'

  $('body').append $$ ->
    @div id: 'jasmine-content'

  reporter = if atom.exitWhenDone
    new jasmine.ConsoleReporter(document, logErrors)
  else
    new jasmine.AtomReporter(document)

#   require specSuite
  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)
  jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)
  jasmineEnv.execute()
