{SoftTab, HardTab, PairedCharacter, SoftWrapIndent} = require './special-token-symbols'

module.exports =
class TokenIterator
  constructor: (line) ->
    @reset(line) if line?

  reset: (@line) ->
    @index = null
    @bufferStart = @line.startBufferColumn
    @bufferEnd = @bufferStart
    @screenStart = 0
    @screenEnd = 0
    @scopes = @line.openScopes.map (id) -> atom.grammars.scopeForId(id)
    @scopeStarts = @scopes.slice()
    @scopeEnds = []
    this

  next: ->
    {tags} = @line

    if @index?
      @index++
      @scopeEnds.length = 0
      @scopeStarts.length = 0
      @bufferStart = @bufferEnd
      @screenStart = @screenEnd
    else
      @index = 0

    while @index < tags.length
      tag = tags[@index]
      if tag < 0
        scope = atom.grammars.scopeForId(tag)
        if tag % 2 is 0
          if @scopeStarts[@scopeStarts.length - 1] is scope
            @scopeStarts.pop()
          else
            @scopeEnds.push(scope)
          @scopes.pop()
        else
          @scopeStarts.push(scope)
          @scopes.push(scope)
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
        return true

    false

  getBufferStart: -> @bufferStart
  getBufferEnd: -> @bufferEnd

  getScreenStart: -> @screenStart
  getScreenEnd: -> @screenEnd

  getScopeStarts: -> @scopeStarts
  getScopeEnds: -> @scopeEnds

  getScopes: -> @scopes

  getText: ->
    @line.text.substring(@screenStart, @screenEnd)

  isSoftTab: ->
    @line.specialTokens[@index] is SoftTab

  isHardTab: ->
    @line.specialTokens[@index] is HardTab

  isSoftWrapIndentation: ->
    @line.specialTokens[@index] is SoftWrapIndent

  isPairedCharacter: ->
    @line.specialTokens[@index] is PairedCharacter

  isAtomic: ->
    @isSoftTab() or @isHardTab() or @isSoftWrapIndentation() or @isPairedCharacter()
