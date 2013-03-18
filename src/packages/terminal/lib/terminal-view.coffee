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
    @buffer = new TerminalBuffer(this)
    @exited = true
    @readData = false
    @setTitle()
    @terminalSize = null
    @updateTimer = false
    @updateDelay = 100

    @on 'mousedown', '.title', (e) => @resizeStarted(e)
    @on 'click', =>
      @hiddenInput.focus()
    @on 'focus', =>
      @hiddenInput.focus()
      @updateTerminalSize()
      @scrollToCursor()
      false
    @on 'textInput', (e) =>
      @input(e.originalEvent.data)
      false
    @on 'keydown', (e) =>
      keystroke = keymap.keystrokeStringForEvent(e)
      if match = keystroke.match /^ctrl-([a-zA-Z])$/
        @input(TerminalBuffer.ctrl(match[1]))
        false
    @subscribe $(window), 'resize', =>
      @updateTerminalSize()

    rootView.command "terminal:enter", => @input("#{TerminalBuffer.carriageReturn}")
    rootView.command "terminal:delete", => @input(TerminalBuffer.deleteKey)
    rootView.command "terminal:backspace", => @input(TerminalBuffer.backspace)
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
    rootView.command "terminal:home", => @input(TerminalBuffer.ctrl("a"))
    rootView.command "terminal:end", => @input(TerminalBuffer.ctrl("e"))

  login: ->
    @process = ChildProcess.exec "/bin/bash", interactive: true, cwd: (project.getPath() || "~"), stdout: (data) =>
      @readData = true if !@readData
      @output(data)
    @process.done () =>
      @exited = true
      @write = () -> false
    @write = @process.write
    @exited = false
    @updateTerminalSize()

  logout: ->
    @write?("", true)

  attach: ->
    @focus()
    @login()

  show: ->
    super
    @login() if @exited

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
    if !@terminalSize?
      @updateTerminalSize()
      @setTerminalSize()

  lastLine: () ->
    $(@content.find("pre").last().get(0))

  update: (ignoreTimer=false) ->
    @setTitle(@buffer.title)
    if @buffer.redrawNeeded
      window.lines = @buffer.lines
      @content.empty()
      @updateLine(line) for line in @buffer.lines
      @buffer.renderedAll()
      @scrollToCursor()
      return
    @updateTimer = false if ignoreTimer
    if @updateTimer
      return
    else if !ignoreTimer && @updateDelay > 0
      window.setTimeout (=> @update(true)), @updateDelay
      @updateTimer = true
    lines = @buffer.getDirtyLines()
    if lines.length > 0
      @updateLine(line) for line in lines
      @buffer.rendered()
      @scrollToCursor()

  updateTerminalSize: () ->
    tester = $("<pre><span class='character'>a</span></pre>")
    @content.append(tester)
    charWidth = parseInt(tester.find("span").css("width"))
    lineHeight = parseInt(tester.css("height"))
    tester.remove()
    windowWidth = parseInt(@css("width"))
    windowHeight = parseInt(@css("height"))
    h = Math.floor(windowHeight / lineHeight) - 1
    w = Math.floor(windowWidth / charWidth) - 1
    return if h <= 0 || w <= 0 || (@terminalSize? && @terminalSize[0] == h && @terminalSize[1] == w)
    @terminalSize = [h, w, charWidth, lineHeight]
    @buffer.setSize([@terminalSize[0], @terminalSize[1]])
    @setTerminalSize()

  getTitle: () -> @title
  setTitle: (text) ->
    @title = ("#{if text? && text.length then "#{text} - " else ""}Atom Terminal")

  getUri: ->
    "terminal:foo"

  scrollToCursor: () ->
    cursor = @content.find("pre span .cursor").parent().position()
    if cursor? then @scrollTop(cursor.top)

  setTerminalSize: () ->
    return if !@terminalSize? || @exited
    @process?.winsize(@terminalSize[0], @terminalSize[1])

  characterColor: (char, color, bgcolor) ->
    if color >= 16 then char.css(color: "##{TerminalBuffer.color(color)}")
    else if color >= 0 then char.addClass("color-#{color}")
    if bgcolor >= 16 then char.css("background-color": "##{TerminalBuffer.color(bgcolor)}")
    else if bgcolor >= 0 then char.addClass("background-#{bgcolor}")

  insertLine: (line) ->
    l = @content.find("pre.line-#{line.number}")
    if !_.contains(@buffer.lines, line)
      l.remove() if line.number >= @buffer.numLines()
      return null
    else if !l.size()
      l = $("<pre>").addClass("line-#{line.number}")
      if line.number < 1
        @content.prepend(l)
      else
        lines = _.sortBy(@content.find("pre"), ((i)-> i.lineNumber = parseInt(i.className.match("line-([0-9]+)")[1])))
        lines.reverse()
        n = 0
        for li in lines
          n = li.lineNumber
          if li.lineNumber < line.number
            $(li).after(l)
            return l
        if line.number < n
          @content.prepend(l)
        else
          @content.append(l)
    l

  updateLine: (line) ->
    l = @insertLine(line)
    return if !l?
    l.empty()
    for c in line.characters
      character = $("<span>").addClass("character").text(c.char)
      character.append($("<span>").addClass("cursor")) if c.cursor
      [color, bgcolor] = [c.color, c.backgroundColor]
      if c.reversed
        color = 7 if color == -1
        bgcolor = 7 if bgcolor == -1
        [color, bgcolor] = [bgcolor, color]
      @characterColor(character, color, bgcolor)
      (character.addClass(s) if c[s] == true) for s in ['bold', 'italic', 'underlined']
      character.css(width: @terminalSize[2]) if c.bold && @terminalSize?
      l.append character