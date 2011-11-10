module.exports =
class Extension
  pane: null

  constructor: ->
    console.log "#{@constructor.name}: Loaded"

  storageNamespace: -> @constructor.name

  startup: ->

  shutdown: ->
