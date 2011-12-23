nakedLoad 'jasmine'
nakedLoad 'jasmine-html'
nakedLoad 'jasmine-focused'

$ = require 'jquery'
coffeekup = require 'coffeekup'

$('head').append coffeekup.render ->
  link rel: "stylesheet", type: "text/css", href: "static/jasmine.css"

$('body').append coffeekup.render ->
  div id: 'jasmine_runner'
  div id: 'jasmine-content'

jasmineEnv = jasmine.getEnv()
trivialReporter = new jasmine.TrivialReporter(document, 'jasmine_runner')

jasmineEnv.addReporter(trivialReporter)

jasmineEnv.specFilter = (spec) -> trivialReporter.specFilter(spec)

require 'spec-suite'
jasmineEnv.execute()

