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
          @closeTags.push(scopeName)
        else
          @openTags.push(scopeName)

    @tagIndex ?= @currentTags.length
    @position = Point(position.row, currentColumn)
    containingTags

  moveToSuccessor: ->
    if @tagIndex is @currentTags.length
      @position = Point(@position.row + 1, 0)
      @currentTags = @tokenizedBuffer.tokenizedLineForRow(@position.row)?.tags
      return false unless @currentTags?
      @tagIndex = 0
    else
      @position = Point(@position.row, @position.column + @currentTags[@tagIndex])
      @tagIndex++

    @openTags = []
    @closeTags = []

    loop
      tag = @currentTags[@tagIndex]
      if tag >= 0 or @tagIndex is @currentTags.length
        if @isAtTagBoundary()
          break
        else
          return @moveToSuccessor()
      else
        scopeName = @grammarRegistry.scopeForId(tag)
        if tag % 2 is 0
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

  isAtTagBoundary: ->
    @closeTags.length > 0 or @openTags.length > 0
