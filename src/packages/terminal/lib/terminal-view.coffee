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
    @div class: "terminal", tabindex: -1, =>
      @div class: "content", outlet: "content", =>
        @pre
      @input class: 'hidden-input', outlet: 'hiddenInput'

  initialize: ->
    super
    @buffer = new TerminalBuffer
    @exited = false
    @readData = false

    @on 'click', =>
      @hiddenInput.focus()

    @on 'focus', =>
      @hiddenInput.focus()
      false

    @on 'textInput', (e) =>
      @input(e.originalEvent.data)
      false

    rootView.command "terminal:enter", =>
      @input(TerminalBuffer.enter)
    rootView.command "terminal:delete", =>
      @input(TerminalBuffer.backspace)
    rootView.command "terminal:paste", =>
      @input(pasteboard.read())
    rootView.command "terminal:left", =>
      @input(TerminalBuffer.escapeSequence("D"))
    rootView.command "terminal:right", =>
      @input(TerminalBuffer.escapeSequence("C"))
    rootView.command "terminal:up", =>
      @input(TerminalBuffer.escapeSequence("A"))
    rootView.command "terminal:down", =>
      @input(TerminalBuffer.escapeSequence("B"))

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
    @scrollToBottom()

  updateLine: (line) ->
    l = @content.find("pre.line-#{line.number}")
    if !l.size()
      l = $("<pre>").addClass("line-#{line.number}")
      @content.append(l)
    else
      l.empty()
    for c in line.characters
      character = $("<span>").addClass("character").text(c.char)
      if c.cursor
        cursor = $("<span>").addClass("cursor")
        character.append(cursor)
      character.addClass("color-#{c.color}").addClass("background-#{c.backgroundColor}")
      for s in ['bold', 'italic', 'underlined']
        character.addClass(s) if c[s] == true
      l.append character