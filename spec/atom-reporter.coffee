path = require 'path'
_ = require 'underscore-plus'
{convertStackTrace} = require 'coffeestack'
{View, $, $$} = require '../src/space-pen-extensions'
grim = require 'grim'
marked = require 'marked'

sourceMaps = {}
formatStackTrace = (spec, message='', stackTrace) ->
  return stackTrace unless stackTrace

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
    lines[index] = line.replace("at #{spec.specDirectory}#{path.sep}", 'at ')

  lines = lines.map (line) -> line.trim()
  lines.join('\n').trim()

module.exports =
class AtomReporter extends View
  @content: ->
    @div class: 'spec-reporter', =>
      @div class: 'padded pull-right', =>
        @button outlet: 'reloadButton', class: 'btn btn-small reload-button', 'Reload Specs'
      @div outlet: 'coreArea', class: 'symbol-area', =>
        @div outlet: 'coreHeader', class: 'symbol-header'
        @ul outlet: 'coreSummary', class: 'symbol-summary list-unstyled'
      @div outlet: 'bundledArea', class: 'symbol-area', =>
        @div outlet: 'bundledHeader', class: 'symbol-header'
        @ul outlet: 'bundledSummary', class: 'symbol-summary list-unstyled'
      @div outlet: 'userArea', class: 'symbol-area', =>
        @div outlet: 'userHeader', class: 'symbol-header'
        @ul outlet: 'userSummary', class: 'symbol-summary list-unstyled'
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

  reportRunnerStarting: (runner) ->
    @handleEvents()
    @startedAt = Date.now()
    specs = runner.specs()
    @totalSpecCount = specs.length
    @addSpecs(specs)
    $(document.body).append this

    @on 'click', '.stack-trace', ->
      $(this).toggleClass('expanded')

    @reloadButton.on 'click', -> require('ipc').send('call-window-method', 'restart')

  reportRunnerResults: (runner) ->
    @updateSpecCounts()
    @status.addClass('alert-success').removeClass('alert-info') if @failedCount is 0
    if @failedCount is 1
      @message.text "#{@failedCount} failure"
    else
      @message.text "#{@failedCount} failures"

  reportSuiteResults: (suite) ->

  reportSpecResults: (spec) ->
    @completeSpecCount++
    spec.endedAt = Date.now()
    @specComplete(spec)
    @updateStatusView(spec)

  reportSpecStarting: (spec) ->
    @specStarted(spec)

  addDeprecations: (spec) ->
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
            @pre class: 'stack-trace padded', formatStackTrace(spec, deprecation.message, fullStack.join('\n'))
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

  updateStatusView: (spec) ->
    if @failedCount > 0
      @status.addClass('alert-danger').removeClass('alert-info')

    @updateSpecCounts()

    rootSuite = spec.suite
    rootSuite = rootSuite.parentSuite while rootSuite.parentSuite
    @message.text rootSuite.description

    time = "#{Math.round((spec.endedAt - @startedAt) / 10)}"
    time = "0#{time}" if time.length < 3
    @time[0].textContent = "#{time[0...-2]}.#{time[-2..]}s"

  addSpecs: (specs) ->
    coreSpecs = 0
    bundledPackageSpecs = 0
    userPackageSpecs = 0
    for spec in specs
      symbol = $$ -> @li id: "spec-summary-#{spec.id}", class: "spec-summary pending"
      switch spec.specType
        when 'core'
          coreSpecs++
          @coreSummary.append symbol
        when 'bundled'
          bundledPackageSpecs++
          @bundledSummary.append symbol
        when 'user'
          userPackageSpecs++
          @userSummary.append symbol

    if coreSpecs > 0
      @coreHeader.text("Core Specs (#{coreSpecs})")
    else
      @coreArea.hide()
    if bundledPackageSpecs > 0
      @bundledHeader.text("Bundled Package Specs (#{bundledPackageSpecs})")
    else
      @bundledArea.hide()
    if userPackageSpecs > 0
      if coreSpecs is 0 and bundledPackageSpecs is 0
        # Package specs being run, show a more descriptive label
        {specDirectory} = specs[0]
        packageFolderName = path.basename(path.dirname(specDirectory))
        packageName = _.undasherize(_.uncamelcase(packageFolderName))
        @userHeader.text("#{packageName} Specs")
      else
        @userHeader.text("User Package Specs (#{userPackageSpecs})")
    else
      @userArea.hide()

  specStarted: (spec) ->
    @runningSpecCount++

  specComplete: (spec) ->
    specSummaryElement = $("#spec-summary-#{spec.id}")
    specSummaryElement.removeClass('pending')
    specSummaryElement.setTooltip(title: spec.getFullName(), container: '.spec-reporter')

    results = spec.results()
    if results.skipped
      specSummaryElement.addClass("skipped")
      @skippedCount++
    else if results.passed()
      specSummaryElement.addClass("passed")
      @passedCount++
    else
      specSummaryElement.addClass("failed")

      specView = new SpecResultView(spec)
      specView.attach()
      @failedCount++
    @addDeprecations(spec)

class SuiteResultView extends View
  @content: ->
    @div class: 'suite', =>
      @div outlet: 'description', class: 'description'

  initialize: (@suite) ->
    @attr('id', "suite-view-#{@suite.id}")
    @description.text(@suite.description)

  attach: ->
    (@parentSuiteView() or $('.results')).append this

  parentSuiteView: ->
    return unless @suite.parentSuite

    if not suiteView = $("#suite-view-#{@suite.parentSuite.id}").view()
      suiteView = new SuiteResultView(@suite.parentSuite)
      suiteView.attach()

    suiteView

class SpecResultView extends View
  @content: ->
    @div class: 'spec', =>
      @div class: 'spec-toggle'
      @div outlet: 'description', class: 'description'
      @div outlet: 'specFailures', class: 'spec-failures'

  initialize: (@spec) ->
    @addClass("spec-view-#{@spec.id}")

    description = @spec.description
    description = "it #{description}" if description.indexOf('it ') isnt 0
    @description.text(description)

    for result in @spec.results().getItems() when not result.passed()
      stackTrace = formatStackTrace(@spec, result.message, result.trace.stack)
      @specFailures.append $$ ->
        @div result.message, class: 'result-message fail'
        @pre stackTrace, class: 'stack-trace padded' if stackTrace

  attach: ->
    @parentSuiteView().append this

  parentSuiteView: ->
    if not suiteView = $("#suite-view-#{@spec.suite.id}").view()
      suiteView = new SuiteResultView(@spec.suite)
      suiteView.attach()

    suiteView
