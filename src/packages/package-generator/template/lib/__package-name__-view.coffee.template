{$$, View} = require 'space-pen'

module.exports =
class __PackageName__View extends View
  @content: ->
    @div class: '__package-name__ overlay from-top', =>
      @div "The __PackageName__ package is Alive! It's ALIVE!", class: "message"

  initialize: (serializeState) ->
    rootView.command "__package-name__:toggle", => @toggle()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    console.log "__PackageName__View was toggled!"
    if @hasParent()
      @detach()
    else
      rootView.append(this)

