{$$} = require 'space-pen'
nakedLoad 'jasmine'
nakedLoad 'jasmine-html'
nakedLoad 'jasmine-focused'

$ = require 'jquery'

document.title = "Benchmark Suite"

$('head').append $$ ->
  @link rel: "stylesheet", type: "text/css", href: "static/jasmine.css"

$('body').append $$ ->
  @div id: 'jasmine_runner'
  @div id: 'jasmine-content'

if atom.exitOnCompletion?
  originalFinishCallback = jasmine.Runner.prototype.finishCallback
  jasmine.Runner.prototype.finishCallback = ->
    originalFinishCallback.call(this)
    $native.exit()

jasmineEnv = jasmine.getEnv()
trivialReporter = new jasmine.TrivialReporter(document, 'jasmine_runner')

jasmineEnv.addReporter(trivialReporter)

jasmineEnv.specFilter = (spec) -> trivialReporter.specFilter(spec)

require 'benchmark-suite'
jasmineEnv.execute()