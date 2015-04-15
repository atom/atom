fs = require 'fs'

module.exports.runSpecSuite = (specSuite, logFile, logErrors=true) ->
  {$, $$} = require '../src/space-pen-extensions'

  window[key] = value for key, value of require '../vendor/jasmine'

  {TerminalReporter} = require 'jasmine-tagged'

  disableFocusMethods() if process.env.JANKY_SHA1

  TimeReporter = require './time-reporter'
  timeReporter = new TimeReporter()

  logStream = fs.openSync(logFile, 'w') if logFile?
  log = (str) ->
    if logStream?
      fs.writeSync(logStream, str)
    else
      process.stderr.write(str)

  if atom.getLoadSettings().exitWhenDone
    reporter = new TerminalReporter
      print: (str) ->
        log(str)
      onComplete: (runner) ->
        fs.closeSync(logStream) if logStream?
        if process.env.JANKY_SHA1
          grim = require 'grim'

          if grim.getDeprecationsLength() > 0
            grim.logDeprecations()
            return atom.exit(1)

        if runner.results().failedCount > 0
          atom.exit(1)
        else
          atom.exit(0)
  else
    AtomReporter = require './atom-reporter'
    reporter = new AtomReporter()

  require specSuite

  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)
  jasmineEnv.addReporter(timeReporter)
  jasmineEnv.setIncludedTags([process.platform])

  $('body').append $$ -> @div id: 'jasmine-content'

  jasmineEnv.execute()

disableFocusMethods = ->
  ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit'].forEach (methodName) ->
    focusMethod = window[methodName]
    window[methodName] = (description) ->
      error = new Error('Focused spec is running on CI')
      focusMethod description, -> throw error
