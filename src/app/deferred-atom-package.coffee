AtomPackage = require 'atom-package'

module.exports =
class DeferredAtomPackage extends AtomPackage

  constructor: ->
    super

    @autoloadStylesheets = false

  activate: (@rootView, @state) ->
    @instance = null
    for event in @loadEvents
      @rootView.command event, (e) => @onLoadEvent(e, @getInstance())
    this

  deactivate: -> @instance?.deactivate?()

  serialize: ->
    if @instance
      @instance.serialize?()
    else
      @state

  getInstance: ->
    unless @instance
      @loadStylesheets()
      InstanceClass = require @instanceClass
      @instance = InstanceClass.activate(@rootView, @state)
    @instance
