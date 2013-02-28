{View, $$} = require 'space-pen'
ScrollView = require 'scroll-view'
TerminalBuffer = require 'terminal/lib/terminal-buffer'
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
    @buffer = new TerminalBuffer
    @exited = false
    @readData = false

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
      @buffer.input(data)
      @update()

  lastLine: () ->
    $(@content.find("pre").last().get(0))

  update: () ->
    @updateLine(line) for line in @buffer.getDirtyLines()
    @buffer.rendered()

  updateLine: (line) ->
    l = @content.find("pre.line-#{line.number}")
    if !l.length
      l = $("<pre>")
      l.addClass("line-#{line.number}")
      @content.append(l)
    l.text(line.text)