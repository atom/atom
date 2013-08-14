$ = require 'jquery'
{View, $$} = require 'space-pen'
_ = require 'underscore'
{convertStackTrace} = require 'coffeestack'

sourceMaps = {}
formatStackTrace = (stackTrace) ->
  return stackTrace unless stackTrace

  jasminePath = require.resolve('jasmine')
  jasminePattern = new RegExp("\\(#{_.escapeRegExp(jasminePath)}:\\d+:\\d+\\)\\s*$")
  convertedLines = []
  for line in stackTrace.split('\n')
    convertedLines.push(line) unless jasminePattern.test(line)

  convertStackTrace(convertedLines.join('\n'), sourceMaps)

module.exports =
class AtomReporter extends View
  @content: ->
    @div id: 'HTMLReporter', class: 'jasmine_reporter', =>
      @div outlet: 'specPopup', class: "spec-popup"
      @div outlet: "suites"
      @div outlet: 'coreArea', =>
        @div outlet: 'coreHeader', class: 'symbolHeader'
        @ul outlet: 'coreSummary', class: 'symbolSummary list-unstyled'
      @div outlet: 'bundledArea', =>
        @div outlet: 'bundledHeader', class: 'symbolHeader'
        @ul outlet: 'bundledSummary', class: 'symbolSummary list-unstyled'
      @div outlet: 'userArea', =>
        @div outlet: 'userHeader', class: 'symbolHeader'
        @ul outlet: 'userSummary', class: 'symbolSummary list-unstyled'
      @div outlet: "status", class: 'status', =>
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
      spec = _.find(window.timedSpecs, (spec) -> description is spec.name)
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
      if specFailures.is(":visible") then element.text "\uf03d" else element.html "\uf03f"
      false

  updateStatusView: (spec) ->
    if @failedCount > 0
      @status.addClass('failed') unless @status.hasClass('failed')

    if @skippedCount
      specCount = "#{@completeSpecCount - @skippedCount}/#{@totalSpecCount - @skippedCount} (#{@skippedCount} skipped)"
    else
      specCount = "#{@completeSpecCount}/#{@totalSpecCount}"
    @specCount.text specCount

    rootSuite = spec.suite
    rootSuite = rootSuite.parentSuite while rootSuite.parentSuite
    @message.text rootSuite.description

    time = "#{Math.round((spec.endedAt - @startedAt.getTime()) / 10)}"
    time = "0#{time}" if time.length < 3
    @time.text "#{time[0...-2]}.#{time[-2..]}s"

  addSpecs: (specs) ->
    coreSpecs = 0
    bundledPackageSpecs = 0
    userPackageSpecs = 0
    for spec in specs
      symbol = $$ -> @li class: "spec-summary pending spec-summary-#{spec.id}"
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
      @coreHeader.text("Core Specs (#{coreSpecs}):")
    else
      @coreArea.hide()
    if bundledPackageSpecs > 0
      @bundledHeader.text("Bundled Package Specs (#{bundledPackageSpecs}):")
    else
      @bundledArea.hide()
    if userPackageSpecs > 0
      @userHeader.text("User Package Specs (#{userPackageSpecs}):")
    else
      @userArea.hide()

  specStarted: (spec) ->
    @runningSpecCount++

  specComplete: (spec) ->
    specSummaryElement = $(".spec-summary-#{spec.id}")
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
    @addClass("suite-view-#{@suite.id}")
    @description.html @suite.description

  attach: ->
    (@parentSuiteView() or $('.results')).append this

  parentSuiteView: ->
    return unless @suite.parentSuite

    if not suiteView = $(".suite-view-#{@suite.parentSuite.id}").view()
      suiteView = new SuiteResultView(@suite.parentSuite)
      suiteView.attach()

    suiteView

class SpecResultView extends View
  @content: ->
    @div class: 'spec', =>
      @div "\uf03d", class: 'spec-toggle'
      @div outlet: 'description', class: 'description'
      @div outlet: 'specFailures', class: 'spec-failures'
  spec: null

  initialize: (@spec) ->
    @addClass("spec-view-#{@spec.id}")
    @description.html @spec.description

    for result in @spec.results().getItems() when not result.passed()
      stackTrace = formatStackTrace(result.trace.stack)
      @specFailures.append $$ ->
        @div result.message, class: 'resultMessage fail'
        @div stackTrace, class: 'stackTrace' if stackTrace

  attach: ->
    @parentSuiteView().append this

  parentSuiteView: ->
    if not suiteView = $(".suite-view-#{@spec.suite.id}").view()
      suiteView = new SuiteResultView(@spec.suite)
      suiteView.attach()

    suiteView
