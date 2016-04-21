{Point} = require 'text-buffer'

module.exports =
class TokenizedBufferIterator
  constructor: (@tokenizedBuffer, @grammarRegistry) ->
    @openTags = null
    @closeTags = null

  seek: (position) ->
    @openTags = []
    @closeTags = []
    @tagIndex = null

    currentLine = @tokenizedBuffer.tokenizedLineForRow(position.row)
    containingTags = currentLine.openScopes.map (id) => @grammarRegistry.scopeForId(id)
    @currentTags = currentLine.tags
    @currentLineLength = currentLine.text.length
    currentColumn = 0
    for tag, index in @currentTags
      if tag >= 0
        if currentColumn >= position.column and @isAtTagBoundary()
          @tagIndex = index
          break
        else
          currentColumn += tag
          containingTags.pop() while @closeTags.shift()
          containingTags.push(tag) while tag = @openTags.shift()
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
    containingTags

  moveToSuccessor: ->
    @openTags = []
    @closeTags = []

    loop
      if @tagIndex is @currentTags.length
        if @isAtTagBoundary()
          break
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

  # Private
  moveToNextLine: ->
    @position = Point(@position.row + 1, 0)
    tokenizedLine = @tokenizedBuffer.tokenizedLineForRow(@position.row)
    return false unless tokenizedLine?
    @currentTags = tokenizedLine.tags
    @currentLineLength = tokenizedLine.text.length
    @tagIndex = 0
    true

  getPosition: ->
    @position

  getCloseTags: ->
    @closeTags.slice()

  getOpenTags: ->
    @openTags.slice()

  isAtTagBoundary: ->
    @closeTags.length > 0 or @openTags.length > 0
