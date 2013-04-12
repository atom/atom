fsUtils = require 'fs-utils'
_ = require 'underscore'

module.exports=
class ImageEditSession
  registerDeserializer(this)

  @canOpen: (path) ->
    _.indexOf([
      '.gif'
      '.jpeg'
      '.jpg'
      '.png'
    ], fsUtils.extension(path), true) >= 0
  
  # Internal:
  @deserialize: (state) ->
    if fsUtils.exists(state.path)
      project.buildEditSession(state.path)
    else
      console.warn "Could not build edit session for path '#{state.path}' because that file no longer exists"

  # Internal: Establishes a new image viewer.
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
