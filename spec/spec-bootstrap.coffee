{$$} = require 'space-pen'
nakedLoad 'jasmine'
nakedLoad 'jasmine-html'
nakedLoad 'jasmine-focused'

$ = require 'jquery'

document.title = "Spec Suite"

$('head').append $$ ->
  @link rel: "stylesheet", type: "text/css", href: "static/jasmine.css"

$('body').append $$ ->
  @div id: 'jasmine-content'

jasmineEnv = jasmine.getEnv()
atomReporter = new jasmine.AtomReporter(document)

jasmineEnv.addReporter(atomReporter)

jasmineEnv.specFilter = (spec) -> atomReporter.specFilter(spec)

require 'spec-suite'
jasmineEnv.execute()

