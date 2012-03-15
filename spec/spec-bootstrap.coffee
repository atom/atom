{$$} = require 'space-pen'
nakedLoad 'jasmine'
nakedLoad 'jasmine-atom-reporter'
nakedLoad 'jasmine-console-reporter'
nakedLoad 'jasmine-focused'

$ = require 'jquery'

document.title = "Spec Suite"

$('head').append $$ ->
  @link rel: "stylesheet", type: "text/css", href: "static/jasmine.css"

$('body').append $$ ->
  @div id: 'jasmine-content'

reporter = if atom.headless
  new jasmine.ConsoleReporter(document)
else
  new jasmine.AtomReporter(document)

require 'spec-suite'
jasmineEnv = jasmine.getEnv()
jasmineEnv.addReporter(reporter)
jasmineEnv.specFilter = (spec) -> reporter.specFilter(spec)
jasmineEnv.execute()