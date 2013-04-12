fsUtils = require 'fs-utils'
_ = require 'underscore'

module.exports=
class ImageEditSession
  registerDeserializer(this)

  # Public: Identifies if a path can be opened by the image viewer.
  #
  # path - The {String} name of the path to check
  #
  # Returns a {Boolean}.
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

  # Internal:
  serialize: ->
    deserializer: 'ImageEditSession'
    path: @path

  # Internal:
  getViewClass: ->
    require 'image-view'

  # Public: Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  # 
  # Returns a {String}.
  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  getUri: -> @path

  getPath: -> @path

  isEqual: (other) ->
    other instanceof ImageEditSession and @getUri() is other.getUri()
