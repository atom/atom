_ = require 'underscore'

module.exports =
class TerminalBuffer
  @enter: String.fromCharCode(10)
  @backspace: String.fromCharCode(8)
  @escape: String.fromCharCode(27)
  @tab: String.fromCharCode(9)
  @ctrl: (c) ->
    base = "a".charCodeAt(0)
    base = "A".charCodeAt(0) if c.charCodeAt(0) < base
    String.fromCharCode(c.charCodeAt(0) - base + 1)
  @escapeSequence: (sequence) -> "#{@escape}[#{sequence}"
  constructor: () ->
    @lines = []
    @dirtyLines = []
    @decsc = [0,0]
    @inEscapeSequence = false
    @resetSGR()
    @cursor = new TerminalCursor(this)
    @addLine(false)
    @redrawNeeded = true
  resetSGR: () ->
    @color = 0
    @backgroundColor = -1
    @bold = false
    @italic = false
    @underlined = false
  length: () ->
    l = 0
    l += line.length() for line in @lines
    l
  screenToLine: (screenCoords) ->
    if @scrollingRegion?
      return [screenCoords[0] + (@scrollingRegion.firstLine - 1), screenCoords[1]]
    screenCoords
  setScrollingRegion: (coords) ->
    @addLine() for n in [1..coords[0]] if @numLines() < coords[0]
    @scrollingRegion = new TerminalScrollingRegion(coords[0], coords[1])
    l = @lastLine()
    @scrollingRegion.firstLine = l.number + 1
    @addLine() for n in [1..@scrollingRegion.height]
  moveCursorTo: (coords) ->
    @cursor.moveTo(@screenToLine(coords))
    n = @numLines()
    if @cursor.y > n
      @addLine(false) for x in [n..(@cursor.line())]
    line = @cursorLine()
    if line? && @cursor.character() >= line.length()
      line.appendCharacter(" ") for x in [line.length()..(@cursor.character())]
  lastLine: () ->
    _.last(@lines)
  cursorLine: () ->
    l = @getLine(@cursor.line())
    l
  setLine: (text, n=-1) ->
    n = @numLines() - 1 if n < 0
    @lines[n].setText(text)
  getLine: (n) ->
    if n >= 0 && n < @numLines() then @lines[n]
  addLine: (moveCursor=true) ->
    @lastLine()?.clearCursor()
    line = new TerminalBufferLine(this, @numLines())
    @lines.push(line)
    @cursor.moveTo([@lastLine().number + 1, 1]) if moveCursor
    line
  numLines: () ->
    @lines.length
  text: () ->
    _.reduce(@lines, (memo, line) ->
      return memo + line.text() + "\n"
    , "")
  enableAlternateBuffer: () ->
    @altBuffer = @lines
    @lines = []
    @addLine()
    @redrawNeeded = true
    @dirtyLines = []
  disableAlternateBuffer: () ->
    return if !@altBuffer?
    @lines = @altBuffer
    @altBuffer = null
    @redrawNeeded = true
    @dirtyLines = []
  addDirtyLine: (line) ->
    @dirtyLines.push(line)
  getDirtyLines: () ->
    _.uniq(@dirtyLines)
  rendered: () ->
    line.rendered() for line in @dirtyLines
    @dirtyLines = []
  backspace: () ->
    # @lastLine().backspace()
    @cursor.x -= 1
    @cursor.x = 1 if @cursor.x < 1
    @cursor.moved()
  input: (text) ->
    @inputCharacter(c) for c in text
  inputCharacter: (c) ->
    # window.console.log [c, c.charCodeAt(0)]
    if @inEscapeSequence
      return @inputEscapeSequence(c)
    switch c.charCodeAt(0)
      when 7 then # Ignore Bell
      when 8 then @backspace()
      when 13 then # Ignore CR
      when 10 then @addLine()
      when 27
        @escape()
      else
        @cursorLine().insertAt(c, @cursor.character())
        @cursor.x += 1
        @cursor.moved()
  inputEscapeSequence: (c) ->
    code = c.charCodeAt(0)
    if (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == "@" # A-Z, a-z, @
      @evaluateEscapeSequence(c, @escapeSequence)
      @inEscapeSequence = false
      @escapeSequence = ""
    else if code != 91 # Ignore [
      @escapeSequence += c
  evaluateEscapeSequence: (type, sequence) ->
    # window.console.log "Terminal: Escape #{sequence} #{type}"
    seq = sequence.split(";")
    switch type
      # when "A" then # Move cursor up
      # when "B" then # Move cursor down
      # when "C" then # Move cursor right
      # when "D" then # Move cursor left
      when "@" # Insert blank character
        num = parseInt(seq[0])
        @cursorLine().appendAt(String.fromCharCode(0), @cursor.character()) for n in [1..num]
      when "H", "f" # Cursor position
        row = parseInt(seq[0])
        col = parseInt(seq[1])
        @moveCursorTo([row, col])
      when "J" # Erase data
        numLines = @numLines() - 1
        start = 0
        cursorLine = @cursor.line()
        if @scrollingRegion?
          start = @scrollingRegion.firstLine - 1
          numLines = start + @scrollingRegion.height - 1
        op = parseInt(seq[0])
        @cursorLine()?.erase(@cursor.character(), op)
        if op == 1
          @getLine(n).erase(0, 2) for n in [start..cursorLine-1]
        else if op == 2
          @getLine(n).erase(0, 2) for n in [start..numLines]
          @cursor.moveTo([1,1])
        else
          @getLine(n).erase(0, 2) for n in [cursorLine+1..numLines]
      when "K" # Erase in line
        op = parseInt(seq[0])
        @cursorLine().erase(@cursor.character(), op)
        @cursorLine().lastCharacter().cursor = true
      when "r" # Set scrollable region
        top = parseInt(seq[0]) || 1
        bottom = parseInt(seq[1]) || 1
        @setScrollingRegion([top,bottom])
      when "P" # Delete characters
        num = parseInt(seq[0])
        @cursorLine().eraseCharacters(@cursor.character(), num)
      when "h"
        num = parseInt(seq[0].replace(/^\?/, ''))
        switch num
          when 0 then # Ignore
          when 1048 # Store cursor position
            @cursor.store()
          when 1049 # Store cursor and switch to alternate buffer
            @cursor.store()
            @enableAlternateBuffer()
          else
            window.console.log "Terminal: Unhandled DECSET #{num}"
      when "l"
        num = parseInt(seq[0].replace(/^\?/, ''))
        switch num
          when 0 then # Ignore
          when 1048 # Restore cursor position
            @cursor.restore()
          when 1049 # Switch to main buffer and restore cursor
            @disableAlternateBuffer()
            @cursor.restore()
          else
            window.console.log "Terminal: Unhandled DECRST #{num}"
      when "m" # SGR (Graphics)
        for s in seq
          i = parseInt(s)
          switch i
            when 1 # Bold
              @bold = true
            when 3 # Italic
              @italic = true
            when 4 # Underlined
              @underlined = true
            when 5 then # Blink: Slow
            when 6 then # Blink: Rapid
            when 7 then # Reverse
            when 8 then # Hidden
            when 22 # Normal
              @bold = false
            when 27 then # Disable reverse
            when 39 # Default text color
              @color = 0
            when 49 # Default background color
              @backgroundColor = -1
            else
              if s == "" || i == 0 # Reset
                @resetSGR()
              else if i >= 30 && i <= 37 # Text color
                @color = i - 30
              else if i >= 90 && i <= 97 # Text color (alt.)
                @color = i - 90
              else if i >= 40 && i <= 47 # Background color
                @backgroundColor = i - 40
              else if i >= 100 && i <= 107 # Background color (alt.)
                @backgroundColor = i - 100
              else
                window.console.log "Terminal: Unhandled SGR sequence #{sequence}#{type} #{i}"
      else
        window.console.log "Terminal: Unhandled escape sequence #{sequence}#{type}"
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
  insertAt: (c, x) ->
    char = @emptyChar()
    char.char = c
    @characters[x] = char
    if x == @length() - 1
      @characters.push(@emptyChar())
    # @characters = _.flatten([@characters.slice(0, x), char, @characters.slice(x, @length())])
    @setDirty()
  appendAt: (c, x) ->
    char = @emptyChar()
    char.char = c
    @characters = _.flatten([@characters.slice(0, x), char, @characters.slice(x, @length())])
    @setDirty()
  lastCharacter: () ->
    _.last(@characters)
  lastVisibleCharacter: () ->
    _.first(_.last(@characters, 2))
  getCharacter: (n) ->
    @characters[n]
  erase: (start, op) ->
    switch op
      when 1 # Clear to beginning of line
        @characters[n] = null for n in [0..(start-1)]
        @characters = _.compact(@characters)
      when 2 # Clear entire line
        @characters = [@emptyChar()]
      else # Clear to end of line
        @characters[n] = null for n in [start..@length()]
        @characters = _.compact(@characters)
        @characters.push(@emptyChar())
    @setDirty()
  eraseCharacters: (start, num) ->
    @characters[n] = null for n in [start..(start+num-1)]
    @characters = _.compact(@characters)
    @setDirty()
  length: () ->
    @characters.length
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
      @bold = buffer.bold
      @italic = buffer.italic
      @underlined = buffer.underlined
    else
      @resetToBlank()
  resetToBlank: () ->
      @char = ""
      @color = 0
      @backgroundColor = 0
      @bold = false
      @italic = false
      @underlined = false
      @cursor = false

class TerminalCursor
  constructor: (@buffer) ->
    @moveTo([1,1])
    @decsc = [1,1]
  store: () ->
    @decsc = [@x, @y]
  restore: () ->
    [@x, @y] = @decsc
  moveTo: (coords) ->
    @y = coords[0]
    @y = 1 if @y < 1
    @x = coords[1]
    @x = 1 if @x < 1
    @moved()
  moved: () ->
    lastLine = @curLine
    @curLine = @buffer.getLine(@line())
    if lastLine && @curLine != lastLine
      lastLine.clearCursor()
    if @curLine && char = @curLine.getCharacter(@character())
      @curLine.clearCursor()
      char.cursor = true
  line: () ->
    @y - 1
  character: () ->
    @x - 1

class TerminalScrollingRegion
  constructor: (top, bottom) ->
    @firstLine = 1
    @height = (bottom - top) + 1