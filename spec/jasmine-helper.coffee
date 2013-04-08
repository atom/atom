window.nakedLoad = (file) ->
  fsUtils = require 'fs-utils'
  file = require.resolve(file)
  code = fsUtils.read(file)
  if fsUtils.extension(file) is '.coffee'
    require('coffee-script').eval(code, filename: file)
  else
    window.eval("#{code}\n//@ sourceURL=#{file}")

module.exports.runSpecSuite = (specSuite, logErrors=true) ->
  {$$} = require 'space-pen'
  nakedLoad 'jasmine'
  nakedLoad 'jasmine-console-reporter'
  require 'jasmine-focused'

  AtomReporter = require 'atom-reporter'

  $ = require 'jquery'
  TimeReporter = require 'time-reporter'

  reporter = if atom.exitWhenDone
    new jasmine.ConsoleReporter(document, logErrors)
  else
    new AtomReporter()

  require specSuite
  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)

  jasmineEnv.addReporter(new TimeReporter())
  jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)

  $('body').append $$ ->
    @div id: 'jasmine-content'

  jasmineEnv.execute()
