{Point} = require 'text-buffer'
{isEqual} = require 'underscore-plus'

module.exports =
class TokenizedBufferIterator
  constructor: (@tokenizedBuffer, @grammarRegistry) ->
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
    @containingTags = @currentLineOpenTags.map (id) => @grammarRegistry.scopeForId(id)
    currentColumn = 0
    for tag, index in @currentTags
      if tag >= 0
        if currentColumn >= position.column and @isAtTagBoundary()
          @tagIndex = index
          break
        else
          currentColumn += tag
          @containingTags.pop() while @closeTags.shift()
          @containingTags.push(tag) while tag = @openTags.shift()
      else
        scopeName = @grammarRegistry.scopeForId(tag)
        if tag % 2 is 0
          if @openTags.length > 0
            @tagIndex = index
            break
          else
            @closeTags.push(scopeName)
        else
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
            @openTags = @currentLineOpenTags.map (id) => @grammarRegistry.scopeForId(id)
            @shouldMoveToNextLine = false
          else if @hasNextLine() and not isEqual(@containingTags, @nextLineOpeningScopes())
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
          scopeName = @grammarRegistry.scopeForId(tag)
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

  hasNextLine: ->
    @tokenizedBuffer.tokenizedLineForRow(@position.row + 1)?

  nextLineOpeningScopes: ->
    line = @tokenizedBuffer.tokenizedLineForRow(@position.row + 1)
    line.openScopes.map (id) => @grammarRegistry.scopeForId(id)

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
