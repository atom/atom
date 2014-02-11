path = require 'path'
_ = require 'underscore-plus'
{convertStackTrace} = require 'coffeestack'
{View, $, $$} = require '../src/space-pen-extensions'

sourceMaps = {}
formatStackTrace = (message='', stackTrace) ->
  return stackTrace unless stackTrace

  jasminePattern = /^\s*at\s+.*\(?.*\/jasmine(-[^\/]*)?\.js:\d+:\d+\)?\s*$/
  convertedLines = []
  for line in stackTrace.split('\n')
    convertedLines.push(line) unless jasminePattern.test(line)

  stackTrace = convertStackTrace(convertedLines.join('\n'), sourceMaps)
  lines = stackTrace.split('\n')

  # Remove first line of stack when it is the same as the error message
  errorMatch = lines[0]?.match(/^Error: (.*)/)
  lines.shift() if message.trim() is errorMatch?[1]?.trim()

  # Remove prefix of lines matching: at [object Object].<anonymous> (path:1:2)
  for line, index in lines
    prefixMatch = line.match(/at \[object Object\]\.<anonymous> \(([^\)]+)\)/)
    lines[index] = "at #{prefixMatch[1]}" if prefixMatch

  lines = lines.map (line) -> line.trim()
  lines.join('\n')

module.exports =
class AtomReporter extends View
  @content: ->
    @div class: 'jasmine_reporter spec-reporter', =>
      @div outlet: 'specPopup', class: "spec-popup alert alert-info"
      @div outlet: "suites"
      @div outlet: 'coreArea', class: 'symbol-area', =>
        @div outlet: 'coreHeader', class: 'symbol-header'
        @ul outlet: 'coreSummary', class: 'symbol-summary list-unstyled'
      @div outlet: 'bundledArea', class: 'symbol-area', =>
        @div outlet: 'bundledHeader', class: 'symbol-header'
        @ul outlet: 'bundledSummary', class: 'symbol-summary list-unstyled'
      @div outlet: 'userArea', class: 'symbol-area', =>
        @div outlet: 'userHeader', class: 'symbol-header'
        @ul outlet: 'userSummary', class: 'symbol-summary list-unstyled'
      @div outlet: "status", class: 'status alert alert-success', =>
        @div outlet: "time", class: 'time'
        @div outlet: "specCount", class: 'spec-count'
        @div outlet: "message", class: 'message'
      @div outlet: "results", class: 'results'

  startedAt: null
  runningSpecCount: 0
  completeSpecCount: 0
  passedCount: 0
  failedCount: 0
  skippedCount: 0
  totalSpecCount: 0
  @timeoutId: 0

  reportRunnerStarting: (runner) ->
    @handleEvents()
    @startedAt = new Date()
    specs = runner.specs()
    @totalSpecCount = specs.length
    @addSpecs(specs)
    $(document.body).append this

  reportRunnerResults: (runner) ->
    @updateSpecCounts()
    if @failedCount == 0
      @message.text "Success!"
    else
      @message.text "Game Over"

  reportSuiteResults: (suite) ->

  reportSpecResults: (spec) ->
    @completeSpecCount++
    spec.endedAt = new Date().getTime()
    @specComplete(spec)
    @updateStatusView(spec)

  reportSpecStarting: (spec) ->
    @specStarted(spec)

  specFilter: (spec) ->
    globalFocusPriority = jasmine.getEnv().focusPriority
    parent = spec.parentSuite ? spec.suite

    if !globalFocusPriority
      true
    else if spec.focusPriority >= globalFocusPriority
      true
    else if not parent
      false
    else
      @specFilter(parent)

  handleEvents: ->
    $(document).on "mouseover", ".spec-summary", ({currentTarget}) =>
      element = $(currentTarget)
      description = element.data("description")
      return unless description

      clearTimeout @timeoutId if @timeoutId?
      @specPopup.show()
      spec = _.find(window.timedSpecs, ({fullName}) -> description is fullName)
      description = "#{description} #{spec.time}ms" if spec
      @specPopup.text description
      {left, top} = element.offset()
      left += 20
      top += 20
      @specPopup.offset({left, top})
      @timeoutId = setTimeout((=> @specPopup.hide()), 3000)

    $(document).on "click", ".spec-toggle", ({currentTarget}) =>
      element = $(currentTarget)
      specFailures = element.parent().find('.spec-failures')
      specFailures.toggle()
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
      @status.addClass('alert-danger').removeClass('alert-success')

    @updateSpecCounts()

    rootSuite = spec.suite
    rootSuite = rootSuite.parentSuite while rootSuite.parentSuite
    @message.text rootSuite.description

    time = "#{Math.round((spec.endedAt - @startedAt.getTime()) / 10)}"
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
    specSummaryElement.data("description", spec.getFullName())

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

class SuiteResultView extends View
  @content: ->
    @div class: 'suite', =>
      @div outlet: 'description', class: 'description'

  suite: null

  initialize: (@suite) ->
    @attr('id', "suite-view-#{@suite.id}")
    @description.html @suite.description

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
  spec: null

  initialize: (@spec) ->
    @addClass("spec-view-#{@spec.id}")

    description = @spec.description
    description = "it #{description}" if description.indexOf('it ') isnt 0
    @description.text(description)

    for result in @spec.results().getItems() when not result.passed()
      stackTrace = formatStackTrace(result.message, result.trace.stack)
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
