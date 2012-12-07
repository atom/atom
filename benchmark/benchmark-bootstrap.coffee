document.title = "Benchmark Suite"

$ = require 'jquery'
_ = require 'underscore'
{$$} = require 'space-pen'

_.extend(global, require 'jasmine')
require 'jasmine-atom-reporter'
require 'jasmine-console-reporter'
_.extend(global, require 'jasmine-focused')

requireStylesheet "jasmine.css"
$('body').append $$ ->
  @div id: 'jasmine-content'

jasmineEnv = jasmine.getEnv()
reporter = if atom.exitWhenDone
  new jasmine.ConsoleReporter(document, logErrors)
else
  new jasmine.AtomReporter(document)
jasmineEnv.addReporter(reporter)
jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)

require 'benchmark-suite'
jasmineEnv.execute()
