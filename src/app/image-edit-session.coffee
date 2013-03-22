fsUtils = require 'fs-utils'

module.exports=
class ImageEditSession
  registerDeserializer(this)

  @deserialize: (state) ->
    if fsUtils.exists(state.path)
      project.buildEditSession(state.path)
    else
      console.warn "Could not build edit session for path '#{state.path}' because that file no longer exists"

  constructor: (@path) ->

  serialize: ->
    deserializer: 'ImageEditSession'
    path: @path

  getViewClass: ->
    require 'image-view'

  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  getUri: -> @path

  getPath: -> @path

  isEqual: (other) ->
    other instanceof ImageEditSession and @getUri() is other.getUri()
