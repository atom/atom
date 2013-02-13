{$$, View} = require 'space-pen'

module.exports =
class ##PackageName##View extends View
  @content: ->
    @div class: '##package-name## overlay from-top', =>
      @div "The ##PackageName## package is Alive! It's ALIVE!", class: "message"

  initialize: (serializeState) ->
    rootView.command "##package-name##:toggle", => @toggle()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    console.log "##PackageName##View was toggled!"
    if @hasParent()
      @detach()
    else
      rootView.append(this)

