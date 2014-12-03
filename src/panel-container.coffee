{Emitter, CompositeDisposable} = require 'event-kit'

module.exports =
class PanelContainer
  constructor: ({@location}={}) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @panels = []

  destroy: ->
    panel.destroy() for panel in @getPanels()
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

  getLocation: -> @location

  isModal: -> @location is 'modal'

  getPanels: -> @panels

  addPanel: (panel) ->
    @subscriptions.add panel.onDidDestroy(@panelDestroyed.bind(this))

    index = @getPanelIndex(panel)
    if index is @panels.length
      @panels.push(panel)
    else
      @panels.splice(index, 0, panel)

    @emitter.emit 'did-add-panel', {panel, index}
    panel

  panelForItem: (item) ->
    for panel in @panels
      return panel if panel.getItem() is item
    null

  panelDestroyed: (panel) ->
    index = @panels.indexOf(panel)
    if index > -1
      @panels.splice(index, 1)
      @emitter.emit 'did-remove-panel', {panel, index}

  getPanelIndex: (panel) ->
    priority = panel.getPriority()
    if @location in ['bottom', 'right']
      for p, i in @panels by -1
        return i + 1 if priority < p.getPriority()
      0
    else
      for p, i in @panels
        return i if priority < p.getPriority()
      @panels.length
