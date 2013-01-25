AtomPackage = require 'atom-package'
_ = require 'underscore'

module.exports =
class DeferredAtomPackage extends AtomPackage

  constructor: ->
    super

    @autoloadStylesheets = false

  activate: (@rootView, @state) ->
    @instance = null
    onLoadEvent = (e) => @onLoadEvent(e, @getInstance())
    if _.isArray(@loadEvents)
      for event in @loadEvents
        @rootView.command(event, onLoadEvent)
    else
      for event, selector of @loadEvents
        @rootView.command(event, selector, onLoadEvent)
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
