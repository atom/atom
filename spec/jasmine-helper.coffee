window.nakedLoad = (file) ->
  fsUtils = require 'fs-utils'
  path = require 'path'
  file = require.resolve(file)
  code = fsUtils.read(file)
  if path.extname(file) is '.coffee'
    require('coffee-script').eval(code, filename: file)
  else
    window.eval("#{code}\n//@ sourceURL=#{file}")

module.exports.runSpecSuite = (specSuite, logErrors=true) ->
  {$$} = require 'space-pen'
  nakedLoad 'jasmine'
  require 'jasmine-focused'

  $ = require 'jquery'
  TimeReporter = require 'time-reporter'
  timeReporter = new TimeReporter()

  if atom.getLoadSettings().exitWhenDone
    {jasmineNode} = require 'jasmine-node/lib/jasmine-node/reporter'
    reporter = new jasmineNode.TerminalReporter
      print: (args...) ->
        process.stderr.write(args...)
      onComplete: (runner) ->
        process.stdout.write('\n')
        timeReporter.logLongestSuites 10, (line) -> process.stdout.write("#{line}\n")
        process.stdout.write('\n')
        timeReporter.logLongestSpecs 10, (line) -> process.stdout.write("#{line}\n")
        atom.exit(runner.results().failedCount > 0 ? 1 : 0)
  else
    AtomReporter = require 'atom-reporter'
    reporter = new AtomReporter()

  require specSuite

  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)
  jasmineEnv.addReporter(timeReporter)

  $('body').append $$ -> @div id: 'jasmine-content'

  jasmineEnv.execute()
