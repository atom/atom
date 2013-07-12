fsUtils = require 'fs-utils'
path = require 'path'
_ = require 'underscore'
archive = require 'ls-archive'
File = require 'file'

module.exports=
class ArchiveEditSession
  registerDeserializer(this)

  @activate: ->
    Project = require 'project'
    Project.registerOpener (filePath) ->
      new ArchiveEditSession(filePath) if archive.isPathSupported(filePath)

  @deserialize: ({path}={}) ->
    path = project.resolve(path)
    if fsUtils.isFileSync(path)
      new ArchiveEditSession(path)
    else
      console.warn "Could not build archive edit session for path '#{path}' because that file no longer exists"

  constructor: (@path) ->
    @file = new File(@path)

  destroy: ->
    @file?.off()

  serialize: ->
    deserializer: 'ArchiveEditSession'
    path: @getUri()

  getViewClass: ->
    require './archive-view'

  getTitle: ->
    if archivePath = @getPath()
      path.basename(archivePath)
    else
      'untitled'

  getUri: -> project?.relativize(@getPath()) ? @getPath()

  getPath: -> @path

  isEqual: (other) ->
    other instanceof ArchiveEditSession and @getUri() is other.getUri()
