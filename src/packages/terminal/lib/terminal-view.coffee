{View, $$} = require 'space-pen'
ScrollView = require 'scroll-view'
_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'
ChildProcess = require 'child-process'

module.exports =
class TerminalView extends ScrollView

  @content: (params) ->
    @div class: "terminal", =>
      @div class: "content", outlet: "content", =>
        @pre
      @input class: 'hidden-input', outlet: 'hiddenInput'

  initialize: ->
    super
    @exited = false
    @readData = false
    @appendLine("", true)

    @on 'focus', =>
      @hiddenInput.focus()
      false

    @on 'textInput', (e) =>
      @input(e.originalEvent.data)
      false

    rootView.command "terminal:enter", =>
      @input(String.fromCharCode(10))

    rootView.command "terminal:delete", =>
      @input(String.fromCharCode(8))

  login: ->
    @process = ChildProcess.exec "/bin/bash", interactive: true, stdout: (data) =>
      @readData = true if !@readData
      @output(data)
    @process.done () =>
      @exited = true
      @write = () -> false
    @write = @process.write

  logout: ->
    @input("\nlogout\n")

  attach: ->
    rootView.append(this)
    @focus()
    @login()

  detach: ->
    @logout()
    @remove()

  input: (data) ->
    return if @exited
    @write?(data)

  output: (data) ->
    if data.length > 0
      @appendData(data)

  lastLine: () ->
    $(@content.find("pre").last().get(0))

  prepareLine: (line) ->
    line.replace(/\r$/, '')

  appendLine: (line, newline=false) ->
    l = @lastLine()
    line = @prepareLine(line)
    if !l? || l.hasClass("newline") || newline
      @content.append $("<pre>").text(line)
    else
      l.append(line)
      l.addClass("newline") if newline

  appendData: (data) ->
    lines = data.split("\n")
    for i, line of lines
      @appendLine(line, i > 0 && i < lines.length)