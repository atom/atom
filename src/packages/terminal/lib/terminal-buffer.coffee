_ = require 'underscore'

module.exports =
class TerminalBuffer
  constructor: () ->
    @lines = []
    @dirtyLines = []
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
  input: (text) ->
    @inputCharacter(c) for c in text
  inputCharacter: (c) ->
    switch c
      when "\r" then # Ignore CR
      when "\n"
        @addLine()
      else
        @lastLine().append(c)
    @moveCursorToEndOfLastLine()

class TerminalBufferLine
  constructor: (@buffer, @number) ->
    @setDirty()
    @characters = [@emptyChar()]
    if text?
      @setText(text)
  emptyChar: () ->
    new TerminalCharacter(this)
  append: (text) ->
    @appendCharacter(c) for c in text
    @setDirty()
  text: () ->
    _.reduce(@characters, (memo, character) ->
      return memo + character.char
    , "")
  appendCharacter: (c) ->
    @lastCharacter().char = c
    @characters.push(@emptyChar())
  lastCharacter: () ->
    _.last(@characters)
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

class TerminalCharacter
  constructor: (@line) ->
    @char = ""
    @resetAttributes()
  resetAttributes: () ->
    @bold = false
    @color = 0
    @cursor = false