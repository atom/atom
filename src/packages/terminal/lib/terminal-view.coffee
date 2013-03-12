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
      @div class: "title", outlet: "title"
      @div class: "content", outlet: "content", =>
        @pre
      @input class: 'hidden-input', outlet: 'hiddenInput'

  initialize: ->
    super
    @buffer = new TerminalBuffer
    @exited = false
    @readData = false
    @setTitle()
    @size = [24,80,8,18]

    @on 'mousedown', '.title', (e) => @resizeStarted(e)
    @on 'click', =>
      @hiddenInput.focus()
    @on 'focus', =>
      @hiddenInput.focus()
      false
    @on 'textInput', (e) =>
      @input(e.originalEvent.data)
      false

    rootView.command "terminal:enter", => @input(TerminalBuffer.enter)
    rootView.command "terminal:delete", => @input(TerminalBuffer.backspace)
    rootView.command "terminal:escape", => @input(TerminalBuffer.escape)
    rootView.command "terminal:tab", => @input(TerminalBuffer.tab)
    for letter in "abcdefghijklmnopqrstuvwxyz"
      do (letter) =>
        key = TerminalBuffer.ctrl(letter)
        rootView.command "terminal:ctrl-#{letter}", => @input(key)
    rootView.command "terminal:paste", => @input(pasteboard.read())
    rootView.command "terminal:left", => @input(TerminalBuffer.escapeSequence("D"))
    rootView.command "terminal:right", => @input(TerminalBuffer.escapeSequence("C"))
    rootView.command "terminal:up", => @input(TerminalBuffer.escapeSequence("A"))
    rootView.command "terminal:down", => @input(TerminalBuffer.escapeSequence("B"))

  login: ->
    @process = ChildProcess.exec "/bin/bash", interactive: true, stdout: (data) =>
      @readData = true if !@readData
      @output(data)
    @process.done () =>
      @exited = true
      @write = () -> false
    @write = @process.write
    @setTerminalSize()

  logout: ->
    @write?("", true)

  attach: ->
    rootView.append(this)
    @updateTerminalSize()
    @focus()
    @login()

  detach: ->
    @logout()
    @remove()

  input: (data) ->
    return if @exited
    @write?(data, false)

  output: (data) ->
    if data.length > 0
      @buffer.input(data)
      @update()

  lastLine: () ->
    $(@content.find("pre").last().get(0))

  update: () ->
    @setTitle(@buffer.title)
    if @buffer.redrawNeeded
      window.lines = @buffer.lines
      @content.empty()
      @updateLine(line) for line in @buffer.lines
      @buffer.renderedAll()
      @content.scrollToTop()
      return
    @updateLine(line) for line in @buffer.getDirtyLines()
    @buffer.rendered()
    @content.scrollToBottom()

  updateTerminalSize: () ->
    tester = $("<pre><span class='character'>a</span></pre>")
    @content.append(tester)
    charWidth = parseInt(tester.find("span").css("width"))
    lineHeight = parseInt(tester.css("height"))
    tester.remove()
    windowWidth = parseInt(@content.css("width"))
    windowHeight = parseInt(@content.css("height"))
    @size = [Math.floor(windowHeight / lineHeight) - 1, Math.floor(windowWidth / charWidth) - 1, charWidth, lineHeight]
    @buffer.setSize([@size[0], @size[1]])

  setTitle: (text) ->
    @title.text("#{if text? && text.length then "#{text} - " else ""}Atom Terminal")

  resizeStarted: (e) =>
    $(document.body).on('mousemove', @resizeTerminal)
    $(document.body).on('mouseup', @resizeStopped)

  resizeStopped: (e) =>
    $(document.body).off('mousemove', @resizeTerminal)
    $(document.body).off('mouseup', @resizeStopped)
    @setTerminalSize()

  resizeTerminal: (e) =>
    height = window.innerWidth - e.pageY
    lineHeight = parseInt(@content.find("pre").css("height"))
    lines = Math.floor(height / lineHeight) - 1
    lines = 1 if lines < 1
    @content.css(height: (lines * lineHeight) + 8)
    @updateTerminalSize()

  setTerminalSize: () ->
    @process?.winsize(@size[0], @size[1])

  updateLine: (line) ->
    l = @content.find("pre.line-#{line.number}")
    if !_.contains(@buffer.lines, line)
      l.remove() if line.number >= @buffer.numLines()
      return
    if !l.size()
      l = $("<pre>").addClass("line-#{line.number}")
      if line.number < 1
        @content.prepend(l)
      else
        n = line.number - 1
        inserted = false
        while n >= 0 && !inserted
          e = @content.find("pre.line-#{n}")
          if e.length > 0
            e.after(l)
            inserted = true
          else
          n--
        if !inserted
          if line.number - 1 > n
            @content.prepend(l)
          else
            @content.append(l)
    else
      l.empty()
    for c in line.characters
      character = $("<span>").addClass("character").text(c.char)
      if c.cursor
        cursor = $("<span>").addClass("cursor")
        character.append(cursor)
      color = c.color
      bgcolor = c.backgroundColor
      if c.reversed
        color = 7 if color == -1
        bgcolor = 7 if bgcolor == -1
        [color, bgcolor] = [bgcolor, color]
      character.addClass("color-#{color}").addClass("background-#{bgcolor}")
      for s in ['bold', 'italic', 'underlined']
        character.addClass(s) if c[s] == true
      character.css(width: @size[2]) if c.bold
      l.append character