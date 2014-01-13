{Model} = require 'theorist'
Serializable = require 'serializable'
PaneContainer = require './pane-container'

module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    paneContainer: -> new PaneContainer
    fullScreen: false

  deserializeParams: (params) ->
    params.paneContainer = PaneContainer.deserialize(params.paneContainer)
    params

  serializeParams: ->
    paneContainer: @paneContainer.serialize()
    fullScreen: atom.isFullScreen()
