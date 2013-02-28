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
    @lines[@lines.length - 1]
  setLine: (text, n=-1) ->
    n = @lines.length - 1 if n < 0
    @lines[n].setText(text)
  getLine: (n) ->
    if n >= 0 && n < @lines.length then @lines[n]
  addLine: () ->
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
  input: (text) ->
    @inputCharacter(c) for c in text
  inputCharacter: (c) ->
    switch c
      when "\r" then # Ignore CR
      when "\n"
        @addLine()
      else
        @lastLine().append(c)

class TerminalBufferLine
  constructor: (@buffer, @number, @text="") ->
    @setDirty()
  append: (text) ->
    @text = @text + text
    @setDirty()
  length: () ->
    @text.length
  setText: (text) ->
    @text = text
    @setDirty()
  setDirty: () ->
    @dirty = true
    @buffer.addDirtyLine(this)
  rendered: () ->
    @dirty = false