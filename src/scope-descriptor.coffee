
# Extended:
module.exports =
class ScopeDescriptor
  @create: (descriptor) ->
    if descriptor instanceof ScopeDescriptor
      descriptor
    else
      new ScopeDescriptor({descriptor})

  ###
  Section: Construction and Destruction
  ###

  # Public:
  constructor: ({@descriptor}) ->

  getScopeChain: ->
    @descriptor
      .map (scope) ->
        scope = ".#{scope}" unless scope[0] is '.'
        scope
      .join(' ')
