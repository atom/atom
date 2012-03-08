{$$} = require 'space-pen'
nakedLoad 'jasmine'
nakedLoad 'jasmine-html'
nakedLoad 'jasmine-focused'

$ = require 'jquery'

$('head').append $$ ->
  @link rel: "stylesheet", type: "text/css", href: "static/jasmine.css"

$('body').append $$ ->
  @div id: 'jasmine_runner'
  @div id: 'jasmine-content'

jasmineEnv = jasmine.getEnv()
trivialReporter = new jasmine.TrivialReporter(document, 'jasmine_runner')

jasmineEnv.addReporter(trivialReporter)

jasmineEnv.specFilter = (spec) -> trivialReporter.specFilter(spec)

require 'benchmark-suite'
jasmineEnv.execute()

