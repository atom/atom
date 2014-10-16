{Emitter, CompositeDisposable} = require 'event-kit'

module.exports =
class PanelContainer
  constructor: ({@viewRegistry, @orientation}) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @panels = []

  destroy: ->
    pane.destroy() for pane in @getPanels()
    @subscriptions.dispose()
    @emitter.emit 'did-destroy', this
    @emitter.dispose()

  ###
  Section: Event Subscription
  ###

  onDidAddPanel: (callback) ->
    @emitter.on 'did-add-panel', callback

  onDidRemovePanel: (callback) ->
    @emitter.on 'did-remove-panel', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Panels
  ###

  getView: -> @viewRegistry.getView(this)

  getOrientation: -> @orientation

  getPanels: -> @panels

  addPanel: (panel) ->
    @subscriptions.add panel.onDidDestroy(@panelDestoryed.bind(this))
    index = @panels.length
    @panels.push(panel)
    @emitter.emit 'did-add-panel', {panel, index}
    panel

  panelDestoryed: (panel) ->
    index = @panels.indexOf(panel)
    if index > -1
      @panels.splice(index, 1)
      @emitter.emit 'did-remove-panel', {panel, index}
