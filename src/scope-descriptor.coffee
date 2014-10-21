# Extended: Wraps an {Array} of `String`s. The Array describes a path from the
# root of the syntax tree to a token including _all_ scope names for the entire
# path.
#
# You can use `ScopeDescriptor`s to get language-specific config settings via
# {Config::get}.
#
# You should not need to create a `ScopeDescriptor` directly.
#
# * {Editor::getRootScopeDescriptor} to get the language's descriptor.
# * {Editor::scopeDescriptorForBufferPosition} to get the descriptor at a
#   specific position in the buffer.
# * {Cursor::getScopeDescriptor} to get a cursor's descriptor based on position.
#
# See the [scopes and scope descriptor guide](https://atom.io/docs/v0.138.0/advanced/scopes-and-scope-descriptors)
# for more information.
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

  # Public: Create a {ScopeDescriptor} object.
  #
  # * `object` {Object}
  #   * `descriptor` {Array} of {String}s
  constructor: ({@descriptor}) ->

  getScopeChain: ->
    @descriptor
      .map (scope) ->
        scope = ".#{scope}" unless scope[0] is '.'
        scope
      .join(' ')
