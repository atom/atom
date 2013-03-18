_ = require 'underscore'
ColorTable = require 'terminal/lib/terminal-color-table'

module.exports =
class TerminalBuffer
  @enter: String.fromCharCode(10)
  @carriageReturn: String.fromCharCode(13)
  @deleteKey: String.fromCharCode(127)
  @backspace: String.fromCharCode(8)
  @bell: String.fromCharCode(7)
  @escape: String.fromCharCode(27)
  @tab: String.fromCharCode(9)
  @color: (n) ->
    ColorTable[n-16]
  @ctrl: (c) ->
    base = "a".charCodeAt(0)
    base = "A".charCodeAt(0) if c.charCodeAt(0) < base
    String.fromCharCode(c.charCodeAt(0) - base + 1)
  @escapeSequence: (sequence,start="[") -> "#{@escape}#{start}#{sequence}"
  constructor: (@view) ->
    @size = [24, 80]
    @reset()
  reset: ->
    @lines = []
    @dirtyLines = []
    @decsc = [0,0]
    @inEscapeSequence = false
    @escapeSequenceStarted = false
    @ignoreEscapeSequence = false
    @endWithBell = false
    @autowrap = false
    @insertmode = false
    @resetSGR()
    @scrollingRegion = null
    @tabstops = []
    @cursor = new TerminalCursor(this)
    @addLine(false)
    @redrawNeeded = true
    @title = ""
    @tabstops = []
  setSize: (size) ->
    @size = size
  resetSGR: () ->
    @color = 0
    @backgroundColor = -1
    @bold = false
    @italic = false
    @underlined = false
    @reversed = false
  length: () ->
    l = 0
    l += line.length() for line in @lines
    l
  screenToLine: (screenCoords) ->
    if @scrollingRegion?
      return [screenCoords[0] + (@scrollingRegion.top - 1), screenCoords[1]]
    screenCoords
  setScrollingRegion: (coords) ->
    start = @numLines() - 1
    if @scrollingRegion? then start = @scrollingRegion.start
    @scrollingRegion = new TerminalScrollingRegion(coords[0], coords[1], start)
  moveCursorTo: (coords) ->
    @cursor.moveTo(@screenToLine(coords))
    @updatedCursor(true)
  updatedCursor: (sgrReset=false) ->
    @resetSGR() if sgrReset
    n = @numLines()
    if @cursor.y > n
      @addLine(false) for x in [n..(@cursor.line())]
    line = @cursorLine()
    if line? && @cursor.character() >= line.length()
      line.appendCharacter(" ") for x in [line.length()..(@cursor.character())]
    @cursor.moved()
  updateLineNumbers: () ->
    (line.number = parseInt(n); line.setDirty()) for n,line of @lines
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
  emptyLine: (n) ->
    new TerminalBufferLine(this, n)
  addLineAt: (n) ->
    line = @emptyLine(0)
    @lines.splice(n, 0, line)
    line
  addLine: (moveCursor=true) ->
    @lastLine()?.clearCursor()
    line = @emptyLine(@numLines())
    @lines.push(line)
    @cursor.moveTo([@lastLine().number + 1, 1]) if moveCursor
    line
  removeLine: (n, num=1) ->
    @lines[n].setDirty()
    @lines.splice(n, num)
    @updateLineNumbers()
  numLines: () ->
    @lines.length
  scrollUp: () ->
    topLine = 0
    bottomLine = @numLines() - 1
    if @scrollingRegion?
      topLine = @scrollingRegion.top - 1
      bottomLine = @scrollingRegion.bottom - 1 if @scrollingRegion.bottom < @numLines()
    @lines[topLine].setDirty()
    @lines.splice(topLine, 1)
    @addLineAt(bottomLine)
    @updateLineNumbers()
  scrollDown: () ->
    topLine = 0
    bottomLine = @numLines() - 1
    if @scrollingRegion?
      topLine = @scrollingRegion.top - 1
      bottomLine = @scrollingRegion.bottom - 1
    if @lines[bottomLine]?
      @lines[bottomLine].setDirty()
      @lines.splice(bottomLine, 1) if @scrollingRegion?
    @addLineAt(topLine)
    @updateLineNumbers()
  eraseData: (op) ->
    numLines = @numLines() - 1
    start = 0
    cursorLine = @cursor.line()
    if @scrollingRegion?
      start = @scrollingRegion.top - 1
      numLines = @scrollingRegion.bottom - 1 - start
    @cursorLine()?.erase(@cursor.character(), op)
    if op == 1
      @getLine(n)?.erase(0, 2) for n in [start..cursorLine-1]
    else if op == 2
      @getLine(n)?.erase(0, 2) for n in [start..numLines]
    else
      @getLine(n)?.erase(0, 2) for n in [cursorLine+1..numLines] if numLines > cursorLine
  eraseInLine: (op) ->
    @cursorLine().erase(@cursor.character(), op)
    @cursorLine().lastCharacter().cursor = true
  text: () ->
    _.reduce(@lines, (memo, line) ->
      return memo + line.text() + "\n"
    , "")
  enableAlternateBuffer: () ->
    [@altBuffer, @lines] = [@lines, []]
    @addLine()
    @scrollingRegion = null
    @redrawNeeded = true
    @dirtyLines = []
  disableAlternateBuffer: () ->
    return if !@altBuffer?
    [@lines, @altBuffer] = [@altBuffer, null]
    @scrollingRegion = null
    @redrawNeeded = true
    @dirtyLines = []
  addDirtyLine: (line) ->
    @dirtyLines.push(line) if _.contains(@lines, line) && !_.contains(@dirtyLines, line)
  getDirtyLines: () ->
    _.uniq(@dirtyLines)
  rendered: () ->
    line.rendered() for line in @dirtyLines
    @dirtyLines = []
  renderedAll: () ->
    line.rendered() for line in @lines
    @dirtyLines = []
    @redrawNeeded = false
  backspace: () ->
    @cursor.x -= 1
    @cursor.x = 1 if @cursor.x < 1
    @updatedCursor()
  moveCursorX: (direction=1) ->
    @cursor.x += direction
    len = @cursorLine().length()
    @cursor.x = len if @cursor.x > len
    @cursor.x = 1 if @cursor.x < 1
    @updatedCursor()
  moveCursorY: (direction=1) ->
    @cursor.y += direction
    len = @numLines()
    @cursor.y = len if @cursor.y > len
    @cursor.y = 1 if @cursor.y < 1
    @updatedCursor(true)
  tab: (direction=1) ->
    found = false
    if @tabstops.length > 0
      if direction > 0
        for stop in @tabstops
          if stop > @cursor.x
            @cursor.x = stop
            found = true
            break
      else
        stops = _.clone(@tabstops)
        stops.reverse()
        for stop in stops
          if stop < @cursor.x
            @cursor.x = stop
            found = true
            break
    if found
    else if direction > 0
      @cursor.x += 8 - ((@cursor.x - 1) % 8) for n in [1..direction]
    else
      @cursor.x -= 8 - ((@cursor.x - 1) % 8) for n in [1..-direction]
    @cursor.x = 1 if @cursor.x < 1
    @updatedCursor()
  newline: (direction=1) ->
    @resetSGR()
    @cursor.y += direction
    @cursor.y = 1 if @cursor.y < 1
    len = @numLines()
    if @scrollingRegion? && @cursor.y > @scrollingRegion.bottom
      @scrollUp() for n in [1..@cursor.y-@scrollingRegion.bottom]
      @cursor.y = @scrollingRegion.bottom
      @updatedCursor(true)
      return
    if @cursor.y > len
      @addLine(!scrollingRegion?) for n in [1..@cursor.y-len]
    @updatedCursor(true)
  insertCharacter: (c) ->
    if @autowrap
      if @cursor.x > @size[1]
        @addLine()
    if !@cursorLine()
      @cursor.y = @lastLine().number
    if !@insertmode
      @cursorLine().insertAt(c, @cursor.character())
    else
      @cursorLine().appendAt(c, @cursor.character())
    @cursor.x += 1
    @updatedCursor()
  input: (text) ->
    @inputCharacter(c) for c in text
  inputCharacter: (c) ->
    # window.console.log [c, c.charCodeAt(0), @numLines()]
    if @inEscapeSequence
      return @inputEscapeSequence(c)
    @inputChars?= []
    @inputChars.push(c)
    switch c.charCodeAt(0)
      when 0 then # Ignore NUL
      when 3 then # Ignore ETX
      when 4 then # Ignore EOT
      when 5 # ENQ
        @view.input(String.fromCharCode(6))
      when 7 then # Ignore BEL
      when 8 then @backspace()
      when 9 # TAB
        @tab()
      when 10, 11, 12 # treat LF, VT and FF as newline
        @newline()
      when 13 # CR
        @cursor.x = 1
        @updatedCursor()
      when 14, 15 then # Ignore SO, SI
      when 17, 19 then # Ignore DC1, DC3 codes
      when 24, 26 then # Ignore CAN
      when 27 # ESC
        @escape()
      else # Input
        @insertCharacter(c)
  inputEscapeSequence: (c) ->
    code = c.charCodeAt(0)
    @clear = false
    if !@escapeSequenceStarted && @escapeSequence.length == 0
      clear = true
      switch c
        when "6" then # DECBI - Back index
        when "7" # DECSC - Store cursor
          @cursor.store()
          break
        when "8" # DECRC - Restore cursor
          @cursor.restore()
          break
        when "9" then # Ignore DECFI - Forward index
        when "=" then # DECKPAM - Application keypad
        when ">" then # DECKPNM - Normal keypad
        when "D" then # DEL - Index
        when "E" then # NEL - Next line
        when "F" then # Cursor to lower left
        when "H" # HTS - Tab set
          @tabstops.push(@cursor.x)
          @tabstops.sort()
        when "M" # RI - Reverse index
          if @cursor.y <= 1
            @scrollDown()
          else
            @moveCursorY(-1)
        when "N", "O" then # SS2, SS3 - Ignore charset
        when "P" then # DCS - Device control string
        when "V" then # SPA - Start guarded area
        when "W" then # EPA - End guarded area
        when "X" then # SOS - Start of string
        when "Z" then # DECID - Return terminal id
        when "\\" then # ST - End of string
        when "^" then # PM - Privacy message
        when "_" then # APC - Application program command
        when "c" then # RIS - Full reset
        when "n", "o", "|", "}", "~" then # LS2, LS3, LS3R, LS2R, LS1R - Ignore charset
        when "(", ")" # Ignore ( and )
          @ignoreEscapeSequence = true
          @escapeSequenceStarted = true
          clear = false
        when "[" # CSI
          @escapeSequenceStarted = true
          clear = false
        when "]" # OSC
          @escapeSequenceStarted = true
          @endWithBell = true
          clear = false
        else
          window.console.log("Unhandled escape sequence ESC #{c} (#{code})")
          clear = false
    else if code == 24 || code == 26 # Cancel escape sequence
      clear = true
    else if (@endWithBell && code == 7) ||(!@endWithBell && ((code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == "@" || c == "`")) # A-Z, a-z, @, `
      @evaluateEscapeSequence(c, @escapeSequence) if !@ignoreEscapeSequence
      clear = true
    else
      @escapeSequence += c
      return
    if clear
      @ignoreEscapeSequence = false
      @inEscapeSequence = false
      @escapeSequenceStarted = false
      @endWithBell = false
      @escapeSequence = ""
  evaluateEscapeSequence: (type, sequence) ->
    if @inputChars.length > 0
      window.console.log _.map @inputChars, (c) ->
        i = c.charCodeAt(0)
        if i < 32 then i
        else c
    @inputChars = []
    window.console.log "Terminal: Escape #{sequence} #{type}"
    seq = sequence.split(";")
    if @endWithBell
      @title = seq[1]
      return
    num = parseInt(seq[0]) || 1
    switch type
      when "@" # ICH - Insert blank character
        @cursorLine().appendAt(String.fromCharCode(0), @cursor.character()) for n in [1..num]
      when "A" # CUU - Move cursor up
        @moveCursorY(-num)
      when "B" # CUD - Move cursor down
        @moveCursorY(num)
      when "C" # CUF - Move cursor right
        @moveCursorX(num)
      when "D" # CUB - Move cursor left
        @moveCursorX(-num)
      when "E" # CNL - Cursor next line
        @newline(num)
      when "F" # CPL - Cursor preceding line
        @newline(-num)
      when "G", "`" # CHA, HPA - Move cursor to position in line
        @moveCursorTo([@cursor.y, num])
      when "H", "f" # CUP, HVP - Cursor position
        col = parseInt(seq[1]) || 1
        @moveCursorTo([num, col])
      when "I" # CHT - Forward tab
        @tab(num)
      when "J" # ED - Erase data
        @eraseData(parseInt(seq[0]))
      when "K" # EL - Erase in line
        @eraseInLine(parseInt(seq[0]))
      when "L" # IL - Insert lines
        if @scrollingRegion?
          @scrollDown() for n in [1..num]
        else
          @addLine(false) for n in [1..num]
      when "M" # DL - Delete lines
        if @scrollingRegion?
          @scrollUp() for n in [1..num]
        else
          @removeLine(@cursor.line(), num)
      when "P" # DCH - Delete characters
        @cursorLine().deleteCharacters(@cursor.character(), num)
      when "S" # SU - Scroll up
        @scrollUp() for n in [1..num]
      when "T" # SD - Scroll down
        if seq.length == 1
          @scrollDown() for n in [1..num]
        else if seq.length == 2
          # Ignore reset features
        else
          # Ignore mouse tracking
      when "X" # ECH - Erase characters
        @cursorLine().eraseCharacters(@cursor.character(), num)
      when "Z" # CBT - Backwards tab
        @tab(-num)
      when "a" # HPR - Character position (relative)
        @moveCursorTo([@cursor.y, @cursor.x + num])
      when "b" # REP - Repeat preceeding character
        c = @cursorLine().getCharacter(@cursor.character() - 1)
        @insertCharacter(c.char) for n in [1..num] if c?
      when "c" # DA - Send device attribute
        @view.input(TerminalBuffer.escapeSequence("?6c"))
      when "d" # VPA - Move cursor to line (absolute)
        @moveCursorTo([num, @cursor.x])
      when "e" # VPR - Move cursor to line (relative)
        @moveCursorTo([@cursor.y + num, @cursor.x])
      when "g" # TBC - Tab clear
        num = parseInt(seq[0]) || 0
        if num == 0 # Clear tabstop in column
          @tabstops = _.without(@tabstops, @cursor.x)
        else if num == 3 # Clear all tabstops
          @tabstops = []
      when "h" # SM - Set mode
        num = parseInt(seq[0].replace(/^\?/, ''))
        switch num
          when 0 then # Ignore
          when 1 then # DECCKM - Application cursor keys
          when 2 then # AM - Keyboard action mode, DECANM
          when 3 then # DECCOLM - 132 column mode
          when 4 # IRM - Insert mode, DECSCLM - Slow scroll
            @insertmode = true
          when 5 then # DECSCNM - Reverse video
          when 6 then # DECOM - Origin mode
          when 7 # DECAWM - Autowrap
            @autowrap = true
          when 8 then # DECARM - Auto-repeat keys
          when 9, 1000 then # Send mouse x, y on button press
          when 10 then # Show toolbar
          when 12 then # Start blinking cursor
          when 18 then # DECPFF - Print form feeed
          when 19 then # DECPEX - Print extend to fullscreen
          when 20 # LNM - Automatic newline
           @automaticnewline = true
          when 25 # DECTCEM - Show cursor
            @cursor.show = true
            @cursor.moved()
          when 30 then # Show scrollbar
          when 35 then # Enable font-shifting
          when 38 then # DECTEK - Tektronix mode
          when 40 then # Allow 80 -> 132 mode
          when 41 then # more(1) fix
          when 42 then # DECNRCM - Notation replacement character sets
          when 44 then # Margin bell
          when 45 then # Reverse wraparound
          when 46 then # Ignore start logging
          when 47, 1047 # Switch to alternate buffer
            @enableAlternateBuffer()
          when 66 then # DECNKM - Application keypad
          when 67 then # DECBKM - Backarrow sends backspace
          when 69 then # DECLRMM - Left and right margin mode
          when 95 then # DECNCSM - Do not clear screen when column is reset
          when 1001 then # Hilite mouse tracking
          when 1002 then # Cell motion mouse tracking
          when 1003 then # All mation mouse tracking
          when 1004 then # Send focus events
          when 1005 then # UTF-8 mode
          when 1006 then # SGR mouse mode
          when 1007 then # Alternate scroll mode
          when 1010 then # Scroll to bottom on output
          when 1011 then # Scroll to bottom on keypress
          when 1015 then # urxvt mouse mode
          when 1034 then # Interpret meta keys
          when 1035 then # Numlock and alt modifiers
          when 1036 then # Esc when meta modifies a key
          when 1037 then # Send del from keypad delete key
          when 1039 then # Esc when alt modifies a key
          when 1040 then # Keep selection when not highlighted
          when 1041 then # Copy to pasteboard
          when 1042 then # Urgency hint on ctrl-G
          when 1043 then # Raise window on ctrl-G
          when 1048 # Store cursor position
            @cursor.store()
          when 1049 # Store cursor and switch to alternate buffer
            @cursor.store()
            @enableAlternateBuffer()
          when 1050 then # Terminfo/termcap function key mode
          when 1051 then # Sun function key mode
          when 1052 then # HP function key mode
          when 1053 then # SCO function key mode
          when 1060 then # Legacy keyboard emulation
          when 1061 then # VT200 keyboard emulation
          when 2004 then # Bracketed paste mode
          else
            window.console.log "Terminal: Unhandled DECSET #{num}"
      # when "i" then # MC - Media copy
      when "l" # RM - Reset mode
        num = parseInt(seq[0].replace(/^\?/, ''))
        decprivate = seq[0].indexof("?") == 0
        switch num
          when 0 then # Ignore
          when 1 then # DECCKM - Application cursor keys
          when 2 then # AM - Keyboard action mode
          when 3 then # DECCOLM - 132 column mode
          when 4 # IRM - Replace mode
            @insertmode = false
          when 5 then # DECSCNM - Reverse video
          when 6 then # DECOM - Origin mode
          when 7 # DECAWM - Autowrap
            @autowrap = false
          when 8 then # DECARM - Auto-repeat keys
          when 9 then # Send mouse x, y on button press
          when 10 then # Show toolbar
          when 12 then # Stop blinking cursor
          when 18 then # DECPFF - Print form feeed
          when 19 then # DECPEX - Print extend to fullscreen
          when 20 # LNM - Normal linefeed
            @automaticnewline = false
          when 25 # DECTCEM - Hide cursor
            @cursor.show = false
            @cursor.moved()
          when 30 then # Show scrollbar
          when 35 then # Enable font-shifting
          when 38 then # DECTEK - Tektronix mode
          when 40 then # Allow 80 -> 132 mode
          when 41 then # more(1) fix
          when 42 then # DECNRCM - Notation replacement character sets
          when 44 then # Margin bell
          when 45 then # Reverse wraparound
          when 46 then # Ignore start logging
          when 47, 1047 # Switch to main buffer
            @disableAlternateBuffer()
          when 66 then # DECNKM - Application keypad
          when 67 then # DECBKM - Backarrow sends backspace
          when 69 then # DECLRMM - Left and right margin mode
          when 95 then # DECNCSM - Do not clear screen when column is reset
          when 1001 then # Hilite mouse tracking
          when 1002 then # Cell motion mouse tracking
          when 1003 then # All mation mouse tracking
          when 1004 then # Send focus events
          when 1005 then # UTF-8 mode
          when 1006 then # SGR mouse mode
          when 1007 then # Alternate scroll mode
          when 1010 then # Scroll to bottom on output
          when 1011 then # Scroll to bottom on keypress
          when 1015 then # urxvt mouse mode
          when 1034 then # Interpret meta keys
          when 1035 then # Numlock and alt modifiers
          when 1036 then # Esc when meta modifies a key
          when 1037 then # Send del from keypad delete key
          when 1039 then # Esc when alt modifies a key
          when 1040 then # Keep selection when not highlighted
          when 1041 then # Copy to pasteboard
          when 1042 then # Urgency hint on ctrl-G
          when 1043 then # Raise window on ctrl-G
          when 1048 # Restore cursor position
            @cursor.restore()
          when 1049 # Switch to main buffer and restore cursor
            @disableAlternateBuffer()
            @cursor.restore()
            @updatedCursor(true)
          when 1050 then # Terminfo/termcap function key mode
          when 1051 then # Sun function key mode
          when 1052 then # HP function key mode
          when 1053 then # SCO function key mode
          when 1060 then # Legacy keyboard emulation
          when 1061 then # VT200 keyboard emulation
          when 2004 then # Bracketed paste mode
          else
            window.console.log "Terminal: Unhandled DECRST #{num}"
      when "m" # SGR - Graphics
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
            when 7 # Reverse
              @reversed = true
            when 8 then # Hidden
            when 22 # Normal
              @bold = false
            when 24 # Not underlined
              @underlined = false
            when 25 then # Not blinking
            when 27 # Disable reverse
              @reversed = false
            when 28 then # Not hidden
            when 38 # Foreground color from palette
              if parseInt(seq[1]) == 5
                @color = parseInt(seq[2])
              return
            when 39 # Default text color
              @color = 0
            when 48 # Background color from palette
              if parseInt(seq[1]) == 5
                @backgroundColor = parseInt(seq[2])
              return
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
                window.console.log "Terminal: Unhandled SGR sequence #{s}#{type} #{i}"
      when "n" # DSR - Device status report
        num = parseInt(seq[0].replace(/^\?/, ''))
        if num == 5 # Are you ok?
          @view.input(TerminalBuffer.escapeSequence("0n"))
        else if num == 6 # Cursor position
          @view.input(TerminalBuffer.escapeSequence("#{@cursor.y};#{@cursor.x}R"))
        else if num == 15 # Printer status
          @view.input(TerminalBuffer.escapeSequence("1n"))
      when "p" then # Ignore pointer mode (>), DECSTR - soft reset (!), DECRQM - ansi mode ($)
      when "q" then # DECLL - Ignore load LEDs, DECSCUSR -set cursor style (sp)
      when "r" # DECSTBM - Set scrollable region
        bottom = parseInt(seq[1]) || 1
        if num == 1 && bottom == 1
          @scrollingRegion = null
        else
          @setScrollingRegion([num,bottom])
      # when "s" then # DECSLRM - Set left and right margins
      # when "t" then # Window attributes
      else
        window.console.log "Terminal: Unhandled escape sequence #{sequence}#{type}"
    @lastLine().lastCharacter()?.reset(this)
  escape: ->
    @inEscapeSequence = true
    @escapeSequence = ""
    @escapeSequenceStarted = false

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
  deleteCharacters: (start,num) ->
    @characters.splice(start, num)
    @setDirty()
  eraseCharacters: (start, num) ->
    @characters[n].resetToBlank() for n in [start..(start+num-1)]
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
      @reversed = buffer.reversed
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
      @reversed = false

class TerminalCursor
  constructor: (@buffer) ->
    @moveTo([1,1])
    @decsc = [1,1]
    @show = true
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
      char.cursor = true if @show
  line: () ->
    @y - 1
  character: () ->
    @x - 1

class TerminalScrollingRegion
  constructor: (top, bottom, @start) ->
    @size = [top, bottom]
    @top = @start + top
    @bottom = @start + bottom
    @height = (bottom - top) + 1