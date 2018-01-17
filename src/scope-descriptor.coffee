# Extended: Wraps an {Array} of `String`s. The Array describes a path from the
# root of the syntax tree to a token including _all_ scope names for the entire
# path.
#
# Methods that take a `ScopeDescriptor` will also accept an {Array} of {String}
# scope names e.g. `['.source.js']`.
#
# You can use `ScopeDescriptor`s to get language-specific config settings via
# {Config::get}.
#
# You should not need to create a `ScopeDescriptor` directly.
#
# * {TextEditor::getRootScopeDescriptor} to get the language's descriptor.
# * {TextEditor::scopeDescriptorForBufferPosition} to get the descriptor at a
#   specific position in the buffer.
# * {Cursor::getScopeDescriptor} to get a cursor's descriptor based on position.
#
# See the [scopes and scope descriptor guide](http://flight-manual.atom.io/behind-atom/sections/scoped-settings-scopes-and-scope-descriptors/)
# for more information.
module.exports =
class ScopeDescriptor
  @fromObject: (scopes) ->
    if scopes instanceof ScopeDescriptor
      scopes
    else
      new ScopeDescriptor({scopes})

  ###
  Section: Construction and Destruction
  ###

  # Public: Create a {ScopeDescriptor} object.
  #
  # * `object` {Object}
  #   * `scopes` {Array} of {String}s
  constructor: ({@scopes}) ->

  # Public: Returns an {Array} of {String}s
  getScopesArray: -> @scopes

  getScopeChain: ->
    @scopes
      .map (scope) ->
        scope = ".#{scope}" unless scope[0] is '.'
        scope
      .join(' ')

  toString: ->
    @getScopeChain()

  isEqual: (other) ->
    if @scopes.length isnt other.scopes.length
      return false
    for scope, i in @scopes
      if scope isnt other.scopes[i]
        return false
    true
