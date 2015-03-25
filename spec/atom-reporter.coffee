path = require 'path'
_ = require 'underscore-plus'
{convertStackTrace} = require 'coffeestack'
{View, $, $$} = require '../src/space-pen-extensions'
grim = require 'grim'
marked = require 'marked'

module.exports =
class AtomReporter
  constructor: ->
    @view = new SpecResultsView
    @rootSuiteDescription = null

  ###
  Section: Jasmine 1.3 API
  ###

  reportRunnerStarting: (runner) ->
    @view.start(runner.specs().length)

  reportRunnerResults: (runner) ->
    @view.finish()

  reportSpecResults: (spec) ->
    specData = @getSpecDataV1(spec)
    @reportSuiteRunning(spec.suite, specData.failures.length > 0)
    @view.markSpecCompleted(spec.suite.id, specData)
    @view.addDeprecations()
    @view.updateStatusView()

  reportSuiteRunning: (suite, hasFailure) ->
    if suite.parentSuite
      @reportSuiteRunning(suite.parentSuite, hasFailure)
    else
      @view.setRootDescription(suite.description)
    @view.addSuiteView(suite.parentSuite?.id, suite) if hasFailure

  ###
  Section: Jasmine 2.0 API
  ###

  jasmineStarted: ({totalSpecsDefined}) ->
    @view.start(totalSpecsDefined)
    @suiteStack = []

  jasmineDone: ->
    @view.finish()

  suiteStarted: (suite) ->
    @view.setRootDescription(suite.description) if @suiteStack.length is 0
    @suiteStack.push(suite)

  suiteDone: (suite) ->
    @suiteStack.pop()

  specDone: (spec) ->
    specData = @getSpecDataV2(spec)
    if specData.failures.length > 0
      parentSuite = null
      for suite in @suiteStack
        @view.addSuiteView(parentSuite?.id, suite)
        parentSuite = suite

    @view.markSpecCompleted(@suiteStack[@suiteStack.length - 1]?.id, specData)
    @view.addDeprecations()
    @view.updateStatusView()

  ###
  Section: Private
  ###

  getSpecDataV1: (spec) ->
    results = spec.results()
    {
      fullName: spec.getFullName()
      description: spec.description
      passed: results.passed()
      skipped: results.skipped
      failures: for item in results.getItems() when not item.passed()
        {
          message: item.message
          stack: item.trace.stack
        }
    }

  getSpecDataV2: (spec) ->
    {
      fullName: spec.fullName
      description: spec.description
      passed: spec.failedExpectations.length is 0
      skipped: spec.pendingReason isnt ""
      failures: for expectation in spec.failedExpectations
        {
          message: expectation.message
          stack: expectation.stack
        }
    }

sourceMaps = {}
formatStackTrace = (message='', stackTrace) ->
  return stackTrace unless stackTrace
  {specDirectory} = atom.getLoadSettings()

  jasminePattern = /^\s*at\s+.*\(?.*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  firstJasmineLinePattern = /^\s*at [/\\].*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  convertedLines = []
  for line in stackTrace.split('\n')
    convertedLines.push(line) unless jasminePattern.test(line)
    break if firstJasmineLinePattern.test(line)

  stackTrace = convertStackTrace(convertedLines.join('\n'), sourceMaps)
  lines = stackTrace.split('\n')

  # Remove first line of stack when it is the same as the error message
  errorMatch = lines[0]?.match(/^Error: (.*)/)
  lines.shift() if message.trim() is errorMatch?[1]?.trim()

  for line, index in lines
    # Remove prefix of lines matching: at [object Object].<anonymous> (path:1:2)
    prefixMatch = line.match(/at \[object Object\]\.<anonymous> \(([^)]+)\)/)
    line = "at #{prefixMatch[1]}" if prefixMatch

    # Relativize locations to spec directory
    lines[index] = line.replace("at #{specDirectory}#{path.sep}", 'at ')

  lines = lines.map (line) -> line.trim()
  lines.join('\n').trim()

class SpecResultsView extends View
  @content: ->
    @div class: 'spec-reporter', =>
      @div class: 'padded pull-right', =>
        @button outlet: 'reloadButton', class: 'btn btn-small reload-button', 'Reload Specs'
      @div outlet: 'coreArea', class: 'symbol-area', =>
        @div outlet: 'coreHeader', class: 'symbol-header'
        @ul outlet: 'coreSummary', class: 'symbol-summary list-unstyled'
      @div outlet: "status", class: 'status alert alert-info', =>
        @div outlet: "time", class: 'time'
        @div outlet: "specCount", class: 'spec-count'
        @div outlet: "message", class: 'message'
      @div outlet: "results", class: 'results'

      @div outlet: "deprecations", class: 'status alert alert-warning', style: 'display: none', =>
        @span outlet: 'deprecationStatus', '0 deprecations'
        @div class: 'deprecation-toggle'
      @div outlet: 'deprecationList', class: 'deprecation-list'

  startedAt: null
  runningSpecCount: 0
  completeSpecCount: 0
  passedCount: 0
  failedCount: 0
  skippedCount: 0
  totalSpecCount: 0
  deprecationCount: 0
  @timeoutId: 0

  start: (totalSpecCount) ->
    @handleEvents()
    @startedAt = Date.now()
    @totalSpecCount = totalSpecCount
    @addSpecs()
    $(document.body).append(this)

    @on 'click', '.stack-trace', ->
      $(this).toggleClass('expanded')

    @reloadButton.on 'click', ->
      require('ipc').send('call-window-method', 'restart')

  finish: ->
    @updateSpecCounts()
    @status.addClass('alert-success').removeClass('alert-info') if @failedCount is 0
    if @failedCount is 1
      @message.text "#{@failedCount} failure"
    else
      @message.text "#{@failedCount} failures"

  addDeprecations: ->
    deprecations = grim.getDeprecations()
    @deprecationCount += deprecations.length
    @deprecations.show() if @deprecationCount > 0
    if @deprecationCount is 1
      @deprecationStatus.text("1 deprecation")
    else
      @deprecationStatus.text("#{@deprecationCount} deprecations")

    for deprecation in deprecations
      @deprecationList.append $$ ->
        @div class: 'padded', =>
          @div class: 'result-message fail deprecation-message', =>
            @raw marked(deprecation.message)

          for stack in deprecation.getStacks()
            fullStack = stack.map ({functionName, location}) ->
              if functionName is '<unknown>'
                "  at #{location}"
              else
                "  at #{functionName} (#{location})"
            @pre class: 'stack-trace padded', formatStackTrace(deprecation.message, fullStack.join('\n'))
    grim.clearDeprecations()

  handleEvents: ->
    $(document).on "click", ".spec-toggle", ({currentTarget}) ->
      element = $(currentTarget)
      specFailures = element.parent().find('.spec-failures')
      specFailures.toggle()
      element.toggleClass('folded')
      false

    $(document).on "click", ".deprecation-toggle", ({currentTarget}) ->
      element = $(currentTarget)
      deprecationList = $(document).find('.deprecation-list')
      deprecationList.toggle()
      element.toggleClass('folded')
      false

  updateSpecCounts: ->
    if @skippedCount
      specCount = "#{@completeSpecCount - @skippedCount}/#{@totalSpecCount - @skippedCount} (#{@skippedCount} skipped)"
    else
      specCount = "#{@completeSpecCount}/#{@totalSpecCount}"
    @specCount[0].textContent = specCount

  setRootDescription: (description) ->
    @message.text(description)

  updateStatusView: ->
    if @failedCount > 0
      @status.addClass('alert-danger').removeClass('alert-info')

    @updateSpecCounts()
    time = "#{Math.round((Date.now() - @startedAt) / 10)}"
    time = "0#{time}" if time.length < 3
    @time[0].textContent = "#{time[0...-2]}.#{time[-2..]}s"

  addSpecs: ->
    for i in [0...@totalSpecCount] by 1
      @coreSummary.append($$ -> @li class: "spec-summary pending")

    {specDirectory} = atom.getLoadSettings()
    packageFolderName = path.basename(path.dirname(specDirectory))
    packageName = _.undasherize(_.uncamelcase(packageFolderName))
    @coreHeader.text("#{packageName} Specs")

  addSuiteView: (parentSuiteId, suite) ->
    unless @getSuiteView(suite.id).length > 0
      unless (parentView = @getSuiteView(parentSuiteId)).length > 0
        parentView = @results
      parentView.append(new SuiteResultView(suite))

  markSpecCompleted: (parentSuiteId, spec) ->
    specSummaryElement = @coreSummary[0].children[@completeSpecCount++]
    specSummaryElement.classList.remove('pending')
    $(specSummaryElement).setTooltip(
      title: spec.fullName
      container: '.spec-reporter'
    )

    if spec.skipped
      specSummaryElement.classList.add("skipped")
      @skippedCount++
    else if spec.passed
      specSummaryElement.classList.add("passed")
      @passedCount++
    else
      specSummaryElement.classList.add("failed")
      @failedCount++
      @getSuiteView(parentSuiteId).append(new SpecResultView(spec))

  getSuiteView: (id) ->
    @find("#suite-view-#{id}")

class SuiteResultView extends View
  @content: ->
    @div class: 'suite', =>
      @div outlet: 'description', class: 'description'

  initialize: ({id, description}) ->
    @attr('id', "suite-view-#{id}")
    @description.text(description)

class SpecResultView extends View
  @content: ->
    @div class: 'spec', =>
      @div class: 'spec-toggle'
      @div outlet: 'description', class: 'description'
      @div outlet: 'specFailures', class: 'spec-failures'

  initialize: ({description, failures}) ->
    description = "it #{description}" if description.indexOf('it ') isnt 0
    @description.text(description)

    for failure in failures
      stackTrace = formatStackTrace(failure.message, failure.stack)
      @specFailures.append $$ ->
        @div failure.message, class: 'result-message fail'
        @pre stackTrace, class: 'stack-trace padded' if stackTrace
    return
