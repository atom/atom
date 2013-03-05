_ = require 'underscore'

module.exports =
class TerminalBuffer
  @enter: String.fromCharCode(10)
  @backspace: String.fromCharCode(8)
  @escape: String.fromCharCode(27)
  @escapeSequence: (sequence) -> "#{@escape}[#{sequence}"
  constructor: () ->
    @lines = []
    @dirtyLines = []
    @inEscapeSequence = false
    @color = 0
    @backgroundColor = 0
    @addLine()
  length: () ->
    l = 0
    l += line.length() for line in @lines
    l
  lastLine: () ->
    _.last(@lines)
  setLine: (text, n=-1) ->
    n = @lines.length - 1 if n < 0
    @lines[n].setText(text)
  getLine: (n) ->
    if n >= 0 && n < @lines.length then @lines[n]
  addLine: () ->
    @lastLine()?.clearCursor()
    @lines.push(new TerminalBufferLine(this, @lines.length))
  numLines: () ->
    @lines.length
  addDirtyLine: (line) ->
    @dirtyLines.push(line)
  getDirtyLines: () ->
    _.uniq(@dirtyLines)
  rendered: () ->
    line.rendered() for line in @dirtyLines
    @dirtyLines = []
  moveCursorToEndOfLastLine: () ->
    @lastLine().clearCursor()
    @lastLine().lastCharacter().cursor = true
  backspace: () ->
    @lastLine().backspace()
  input: (text) ->
    @inputCharacter(c) for c in text
  inputCharacter: (c) ->
    if @inEscapeSequence
      return @inputEscapeSequence(c)
    switch c.charCodeAt(0)
      when 8 then @backspace()
      when 13 then # Ignore CR
      when 10 then @addLine()
      when 27 then @escape()
      else
        @lastLine().append(c)
    @moveCursorToEndOfLastLine()
  inputEscapeSequence: (c) ->
    code = c.charCodeAt(0)
    if (code >= 65 && code <= 90) || (code >= 97 && code <= 122) # A-Z, a-z
      @evaluateEscapeSequence(c, @escapeSequence)
      @inEscapeSequence = false
      @escapeSequence = ""
    else if code != 91 # Ignore [
      @escapeSequence += c
  evaluateEscapeSequence: (type, sequence) ->
    switch type
      when "m" # SGR (Graphics)
        i = parseInt(sequence)
        if i == 0 # Reset
          @color = 0
          @backgroundColor = 0
        if i >= 30 && i <= 37 # Text color
          @color = i - 30
        if i >= 40 && i <= 47 # Background color
          @backgroundColor = i - 40
    @lastLine().lastCharacter()?.reset(this)
  escape: ->
    @inEscapeSequence = true
    @escapeSequence = ""

class TerminalBufferLine
  constructor: (@buffer, @number) ->
    @setDirty()
    @characters = [@emptyChar()]
    if text?
      @setText(text)
  emptyChar: () ->
    new TerminalCharacter(this, @buffer)
  append: (text) ->
    @appendCharacter(c) for c in text
    @setDirty()
  text: () ->
    _.reduce(@characters, (memo, character) ->
      return memo + character.char
    , "")
  appendCharacter: (c) ->
    @lastCharacter().char = c
    char = @emptyChar()
    @characters.push(char)
  lastCharacter: () ->
    _.last(@characters)
  lastVisibleCharacter: () ->
    _.first(_.last(@characters, 2))
  length: () ->
    @text().length
  setText: (text) ->
    @characters = []
    @append(text)
    @setDirty()
  setDirty: () ->
    @dirty = true
    @buffer.addDirtyLine(this)
  rendered: () ->
    @dirty = false
  clearCursor: () ->
    c.cursor = false for c in @characters
    @setDirty()
  backspace: () ->
    c = @lastVisibleCharacter()
    c.cursor = true
    c.char = ''
    @characters.pop() if @lastCharacter() != @lastVisibleCharacter()

class TerminalCharacter
  constructor: (@line, buffer) ->
    @char = ""
    @reset(buffer)
  reset: (buffer) ->
    if buffer?
      @color = buffer.color
      @backgroundColor = buffer.backgroundColor
    else
      @bold = false
      @color = 0
      @backgroundColor = 0
      @cursor = false