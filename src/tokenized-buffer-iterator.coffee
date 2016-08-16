{Point} = require 'text-buffer'

module.exports =
class TokenizedBufferIterator
  constructor: (@tokenizedBuffer) ->
    @openTags = null
    @closeTags = null
    @containingTags = null

  seek: (position) ->
    @openTags = []
    @closeTags = []
    @tagIndex = null

    currentLine = @tokenizedBuffer.tokenizedLineForRow(position.row)
    @currentTags = currentLine.tags
    @currentLineOpenTags = currentLine.openScopes
    @currentLineLength = currentLine.text.length
    @containingTags = @currentLineOpenTags.map (id) => @tokenizedBuffer.grammar.scopeForId(id)
    currentColumn = 0

    for tag, index in @currentTags
      if tag >= 0
        if currentColumn is position.column
          @tagIndex = index
          break
        else
          currentColumn += tag
          @containingTags.pop() while @closeTags.shift()
          @containingTags.push(openTag) while openTag = @openTags.shift()
          if currentColumn > position.column
            @tagIndex = index
            break
      else
        scopeName = @tokenizedBuffer.grammar.scopeForId(tag)
        if tag % 2 is 0 # close tag
          if @openTags.length > 0
            if currentColumn is position.column
              @tagIndex = index
              break
            else
              @containingTags.pop() while @closeTags.shift()
              @containingTags.push(openTag) while openTag = @openTags.shift()
          @closeTags.push(scopeName)
        else # open tag
          @openTags.push(scopeName)

    @tagIndex ?= @currentTags.length
    @position = Point(position.row, Math.min(@currentLineLength, currentColumn))
    @containingTags.slice()

  moveToSuccessor: ->
    @containingTags.pop() for tag in @closeTags
    @containingTags.push(tag) for tag in @openTags
    @openTags = []
    @closeTags = []

    loop
      if @tagIndex is @currentTags.length
        if @isAtTagBoundary()
          break
        else
          if @shouldMoveToNextLine
            @moveToNextLine()
            @openTags = @currentLineOpenTags.map (id) => @tokenizedBuffer.grammar.scopeForId(id)
            @shouldMoveToNextLine = false
          else if @nextLineHasMismatchedContainingTags()
            @closeTags = @containingTags.slice().reverse()
            @containingTags = []
            @shouldMoveToNextLine = true
          else
            return false unless @moveToNextLine()
      else
        tag = @currentTags[@tagIndex]
        if tag >= 0
          if @isAtTagBoundary()
            break
          else
            @position = Point(@position.row, Math.min(@currentLineLength, @position.column + @currentTags[@tagIndex]))
        else
          scopeName = @tokenizedBuffer.grammar.scopeForId(tag)
          if tag % 2 is 0
            if @openTags.length > 0
              break
            else
              @closeTags.push(scopeName)
          else
            @openTags.push(scopeName)
        @tagIndex++

    true

  getPosition: ->
    @position

  getCloseTags: ->
    @closeTags.slice()

  getOpenTags: ->
    @openTags.slice()

  ###
  Section: Private Methods
  ###

  nextLineHasMismatchedContainingTags: ->
    if line = @tokenizedBuffer.tokenizedLineForRow(@position.row + 1)
      return true if line.openScopes.length isnt @containingTags.length

      for i in [0...@containingTags.length] by 1
        if @containingTags[i] isnt @tokenizedBuffer.grammar.scopeForId(line.openScopes[i])
          return true
      false
    else
      false

  moveToNextLine: ->
    @position = Point(@position.row + 1, 0)
    if tokenizedLine = @tokenizedBuffer.tokenizedLineForRow(@position.row)
      @currentTags = tokenizedLine.tags
      @currentLineLength = tokenizedLine.text.length
      @currentLineOpenTags = tokenizedLine.openScopes
      @tagIndex = 0
      true
    else
      false

  isAtTagBoundary: ->
    @closeTags.length > 0 or @openTags.length > 0
