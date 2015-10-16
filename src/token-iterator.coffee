{SoftTab, HardTab, PairedCharacter, SoftWrapIndent} = require './special-token-symbols'
{isDoubleWidthCharacter, isHalfWidthCharacter, isKoreanCharacter} = require './text-utils'

module.exports =
class TokenIterator
  constructor: ({@grammarRegistry}, line, enableScopes) ->
    @reset(line, enableScopes) if line?

  reset: (@line, @enableScopes=true) ->
    @index = null
    @bufferStart = @line.startBufferColumn
    @bufferEnd = @bufferStart
    @screenStart = 0
    @screenEnd = 0
    @resetScopes() if @enableScopes
    this

  next: ->
    {tags} = @line

    if @index?
      @index++
      @bufferStart = @bufferEnd
      @screenStart = @screenEnd
      @clearScopeStartsAndEnds() if @enableScopes
    else
      @index = 0

    while @index < tags.length
      tag = tags[@index]
      if tag < 0
        @handleScopeForTag(tag) if @enableScopes
        @index++
      else
        if @isHardTab()
          @screenEnd = @screenStart + tag
          @bufferEnd = @bufferStart + 1
        else if @isSoftWrapIndentation()
          @screenEnd = @screenStart + tag
          @bufferEnd = @bufferStart + 0
        else
          @screenEnd = @screenStart + tag
          @bufferEnd = @bufferStart + tag

        @text = @line.text.substring(@screenStart, @screenEnd)
        return true

    false

  resetScopes: ->
    @scopes = @line.openScopes.map (id) => @grammarRegistry.scopeForId(id)
    @scopeStarts = @scopes.slice()
    @scopeEnds = []

  clearScopeStartsAndEnds: ->
    @scopeEnds.length = 0
    @scopeStarts.length = 0

  handleScopeForTag: (tag) ->
    scope = @grammarRegistry.scopeForId(tag)
    if tag % 2 is 0
      if @scopeStarts[@scopeStarts.length - 1] is scope
        @scopeStarts.pop()
      else
        @scopeEnds.push(scope)
      @scopes.pop()
    else
      @scopeStarts.push(scope)
      @scopes.push(scope)

  getBufferStart: -> @bufferStart
  getBufferEnd: -> @bufferEnd

  getScreenStart: -> @screenStart
  getScreenEnd: -> @screenEnd

  getScopeStarts: -> @scopeStarts
  getScopeEnds: -> @scopeEnds

  getScopes: -> @scopes

  getText: -> @text

  isSoftTab: ->
    @line.specialTokens[@index] is SoftTab

  isHardTab: ->
    @line.specialTokens[@index] is HardTab

  isSoftWrapIndentation: ->
    @line.specialTokens[@index] is SoftWrapIndent

  isPairedCharacter: ->
    @line.specialTokens[@index] is PairedCharacter

  hasDoubleWidthCharacterAt: (charIndex) ->
    isDoubleWidthCharacter(@getText()[charIndex])

  hasHalfWidthCharacterAt: (charIndex) ->
    isHalfWidthCharacter(@getText()[charIndex])

  hasKoreanCharacterAt: (charIndex) ->
    isKoreanCharacter(@getText()[charIndex])

  isAtomic: ->
    @isSoftTab() or @isHardTab() or @isSoftWrapIndentation() or @isPairedCharacter()
