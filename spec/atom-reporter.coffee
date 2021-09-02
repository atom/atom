path = require 'path'
process = require 'process'
_ = require 'underscore-plus'
grim = require 'grim'
listen = require '../src/delegated-listener'
ipcHelpers = require '../src/ipc-helpers'

formatStackTrace = (spec, message='', stackTrace) ->
  return stackTrace unless stackTrace

  # at ... (.../jasmine.js:1:2)
  jasminePattern = /^\s*at\s+.*\(?.*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  # at jasmine.Something... (.../jasmine.js:1:2)
  firstJasmineLinePattern = /^\s*at\s+jasmine\.[A-Z][^\s]*\s+\(?.*[/\\]jasmine(-[^/\\]*)?\.js:\d+:\d+\)?\s*$/
  lines = []
  for line in stackTrace.split('\n')
    break if firstJasmineLinePattern.test(line)
    lines.push(line) unless jasminePattern.test(line)

  # Remove first line of stack when it is the same as the error message
  errorMatch = lines[0]?.match(/^Error: (.*)/)
  lines.shift() if message.trim() is errorMatch?[1]?.trim()

  lines = lines.map (line) ->
    # Only format actual stacktrace lines
    if /^\s*at\s/.test(line)
      # Needs to occur before path relativization
      if process.platform is 'win32' and /file:\/\/\//.test(line)
        # file:///C:/some/file -> C:\some\file
        line = line.replace('file:///', '').replace(///#{path.posix.sep}///g, path.win32.sep)

      line = line.trim()
        # at jasmine.Spec.<anonymous> (path:1:2) -> at path:1:2
        .replace(/^at jasmine\.Spec\.<anonymous> \(([^)]+)\)/, 'at $1')
        # at jasmine.Spec.it (path:1:2) -> at path:1:2
        .replace(/^at jasmine\.Spec\.f*it \(([^)]+)\)/, 'at $1')
        # at it (path:1:2) -> at path:1:2
        .replace(/^at f*it \(([^)]+)\)/, 'at $1')
        # at spec/file-test.js -> at file-test.js
        .replace(spec.specDirectory + path.sep, '')

    return line

  lines.join('\n').trim()

module.exports =
class AtomReporter
  constructor: ->
    @element = document.createElement('div')
    @element.classList.add('spec-reporter-container')
    @element.innerHTML = """
      <div class="spec-reporter">
        <div class="padded pull-right">
          <button outlet="reloadButton" class="btn btn-small reload-button">Reload Specs</button>
        </div>
        <div outlet="coreArea" class="symbol-area">
          <div outlet="coreHeader" class="symbol-header"></div>
          <ul outlet="coreSummary"class="symbol-summary list-unstyled"></ul>
        </div>
        <div outlet="bundledArea" class="symbol-area">
          <div outlet="bundledHeader" class="symbol-header"></div>
          <ul outlet="bundledSummary"class="symbol-summary list-unstyled"></ul>
        </div>
        <div outlet="userArea" class="symbol-area">
          <div outlet="userHeader" class="symbol-header"></div>
          <ul outlet="userSummary"class="symbol-summary list-unstyled"></ul>
        </div>
        <div outlet="status" class="status alert alert-info">
          <div outlet="time" class="time"></div>
          <div outlet="specCount" class="spec-count"></div>
          <div outlet="message" class="message"></div>
        </div>
        <div outlet="results" class="results"></div>
        <div outlet="deprecations" class="status alert alert-warning" style="display: none">
          <span outlet="deprecationStatus">0 deprecations</span>
          <div class="deprecation-toggle"></div>
        </div>
        <div outlet="deprecationList" class="deprecation-list"></div>
      </div>
    """

    for element in @element.querySelectorAll('[outlet]')
      this[element.getAttribute('outlet')] = element

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
    document.body.appendChild(@element)

  reportRunnerResults: (runner) ->
    @updateSpecCounts()
    if @failedCount is 0
      @status.classList.add('alert-success')
      @status.classList.remove('alert-info')

    if @failedCount is 1
      @message.textContent = "#{@failedCount} failure"
    else
      @message.textContent = "#{@failedCount} failures"

  reportSuiteResults: (suite) ->

  reportSpecResults: (spec) ->
    @completeSpecCount++
    spec.endedAt = Date.now()
    @specComplete(spec)
    @updateStatusView(spec)

  reportSpecStarting: (spec) ->
    @specStarted(spec)

  handleEvents: ->
    listen document, 'click', '.spec-toggle', (event) ->
      specFailures = event.currentTarget.parentElement.querySelector('.spec-failures')

      if specFailures.style.display is 'none'
        specFailures.style.display = ''
        event.currentTarget.classList.remove('folded')
      else
        specFailures.style.display = 'none'
        event.currentTarget.classList.add('folded')

      event.preventDefault()

    listen document, 'click', '.deprecation-list', (event) ->
      deprecationList = event.currentTarget.parentElement.querySelector('.deprecation-list')

      if deprecationList.style.display is 'none'
        deprecationList.style.display = ''
        event.currentTarget.classList.remove('folded')
      else
        deprecationList.style.display = 'none'
        event.currentTarget.classList.add('folded')

      event.preventDefault()

    listen document, 'click', '.stack-trace', (event) ->
      event.currentTarget.classList.toggle('expanded')

    @reloadButton.addEventListener('click', -> ipcHelpers.call('window-method', 'reload'))

  updateSpecCounts: ->
    if @skippedCount
      specCount = "#{@completeSpecCount - @skippedCount}/#{@totalSpecCount - @skippedCount} (#{@skippedCount} skipped)"
    else
      specCount = "#{@completeSpecCount}/#{@totalSpecCount}"
    @specCount.textContent = specCount

  updateStatusView: (spec) ->
    if @failedCount > 0
      @status.classList.add('alert-danger')
      @status.classList.remove('alert-info')

    @updateSpecCounts()

    rootSuite = spec.suite
    rootSuite = rootSuite.parentSuite while rootSuite.parentSuite
    @message.textContent = rootSuite.description

    time = "#{Math.round((spec.endedAt - @startedAt) / 10)}"
    time = "0#{time}" if time.length < 3
    @time.textContent = "#{time[0...-2]}.#{time[-2..]}s"

  specTitle: (spec) ->
    parentDescs = []
    s = spec.suite
    while s
      parentDescs.unshift(s.description)
      s = s.parentSuite

    suiteString = ""
    indent = ""
    for desc in parentDescs
      suiteString += indent + desc + "\n"
      indent += "  "

    "#{suiteString} #{indent} it #{spec.description}"

  addSpecs: (specs) ->
    coreSpecs = 0
    bundledPackageSpecs = 0
    userPackageSpecs = 0
    for spec in specs
      symbol = document.createElement('li')
      symbol.setAttribute('id', "spec-summary-#{spec.id}")
      symbol.setAttribute('title', @specTitle(spec))
      symbol.className = "spec-summary pending"
      switch spec.specType
        when 'core'
          coreSpecs++
          @coreSummary.appendChild symbol
        when 'bundled'
          bundledPackageSpecs++
          @bundledSummary.appendChild symbol
        when 'user'
          userPackageSpecs++
          @userSummary.appendChild symbol

    if coreSpecs > 0
      @coreHeader.textContent = "Core Specs (#{coreSpecs})"
    else
      @coreArea.style.display = 'none'
    if bundledPackageSpecs > 0
      @bundledHeader.textContent = "Bundled Package Specs (#{bundledPackageSpecs})"
    else
      @bundledArea.style.display = 'none'
    if userPackageSpecs > 0
      if coreSpecs is 0 and bundledPackageSpecs is 0
        # Package specs being run, show a more descriptive label
        {specDirectory} = specs[0]
        packageFolderName = path.basename(path.dirname(specDirectory))
        packageName = _.undasherize(_.uncamelcase(packageFolderName))
        @userHeader.textContent = "#{packageName} Specs"
      else
        @userHeader.textContent = "User Package Specs (#{userPackageSpecs})"
    else
      @userArea.style.display = 'none'

  specStarted: (spec) ->
    @runningSpecCount++

  specComplete: (spec) ->
    specSummaryElement = document.getElementById("spec-summary-#{spec.id}")
    specSummaryElement.classList.remove('pending')

    results = spec.results()
    if results.skipped
      specSummaryElement.classList.add("skipped")
      @skippedCount++
    else if results.passed()
      specSummaryElement.classList.add("passed")
      @passedCount++
    else
      specSummaryElement.classList.add("failed")

      specView = new SpecResultView(spec)
      specView.attach()
      @failedCount++

class SuiteResultView
  constructor: (@suite) ->
    @element = document.createElement('div')
    @element.className = 'suite'
    @element.setAttribute('id', "suite-view-#{@suite.id}")
    @description = document.createElement('div')
    @description.className = 'description'
    @description.textContent = @suite.description
    @element.appendChild(@description)

  attach: ->
    (@parentSuiteView() or document.querySelector('.results')).appendChild(@element)

  parentSuiteView: ->
    return unless @suite.parentSuite

    unless suiteViewElement = document.querySelector("#suite-view-#{@suite.parentSuite.id}")
      suiteView = new SuiteResultView(@suite.parentSuite)
      suiteView.attach()
      suiteViewElement = suiteView.element

    suiteViewElement

class SpecResultView
  constructor: (@spec) ->
    @element = document.createElement('div')
    @element.className = 'spec'
    @element.innerHTML = """
      <div class='spec-toggle'></div>
      <div outlet='description' class='description'></div>
      <div outlet='specFailures' class='spec-failures'></div>
    """
    @description = @element.querySelector('[outlet="description"]')
    @specFailures = @element.querySelector('[outlet="specFailures"]')

    @element.classList.add("spec-view-#{@spec.id}")

    description = @spec.description
    description = "it #{description}" if description.indexOf('it ') isnt 0
    @description.textContent = description

    for result in @spec.results().getItems() when not result.passed()
      stackTrace = formatStackTrace(@spec, result.message, result.trace.stack)

      resultElement = document.createElement('div')
      resultElement.className = 'result-message fail'
      resultElement.textContent = result.message
      @specFailures.appendChild(resultElement)

      if stackTrace
        traceElement = document.createElement('pre')
        traceElement.className = 'stack-trace padded'
        traceElement.textContent = stackTrace
        @specFailures.appendChild(traceElement)

  attach: ->
    @parentSuiteView().appendChild(@element)

  parentSuiteView: ->
    unless suiteViewElement = document.querySelector("#suite-view-#{@spec.suite.id}")
      suiteView = new SuiteResultView(@spec.suite)
      suiteView.attach()
      suiteViewElement = suiteView.element

    suiteViewElement
