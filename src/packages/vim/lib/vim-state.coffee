
class VimMotion
  constructor: (@name, @event, @count) ->
  perform: (target) ->
    window.console.log "Performing motion #{@name} (#{@count}) with event #{@event}"
    target.trigger(@event) for n in [1..@count]
  performSelect: (target) ->
    event = @event.replace(/move/, 'select')
    window.console.log "Performing motion #{@name} (#{@count}) with event #{event}"
    target.trigger(event) for n in [1..@count]

class VimOperation
  constructor: (@name, @callback, @vim) ->
    @motion = null
  perform: (@target, @motion) ->
    window.console.log "Beginning operation #{@name}"
    @callback.apply(this)
    window.console.log "Finished operation #{@name}"
  performEvent: (event) ->
    @target.trigger(event)
  performMotion: ->
    @motion.perform(@target) if @motion?
  performSelectMotion: ->
    @motion.performSelect(@target) if @motion?

module.exports =
class VimState
  constructor: (@target, @vim) ->
    @resetState()
    for m,event of @motionEvents
      do (m, event) =>
        @target.command "vim:motion-#{m}", => @motion(m)
    for o,callback of @operations
      do (o) =>
        @target.command "vim:operation-#{o}", => @operation(o)
    for a,options of @aliases
      do (a) =>
        @target.command "vim:alias-#{a}", => @alias(a)
  motion: (type) ->
    event = @motionEvents[type]
    m = new VimMotion(type, event, @_count)
    @_operation.perform(@target, m)
    @resetState()
  defaultMotion: () ->
    new VimMotion('line', @motionEvents['line'], @_count)
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @enterState "count"
    @_count = @_count * 10 + n if n?
    @stateUpdated()
    @_count
  count: (n) ->
    @_count = n if n?
    @_count
  visual: () ->
    @vim.visual
  defaultOperation: () ->
    if @visual() then 'select' else 'move'
  buildOperation: (type) ->
    type = @defaultOperation() if !@operations[type]?
    new VimOperation(type, @operations[type], @vim)
  operation: (type) ->
    if @visual()
      @_operation = @buildOperation(type)
      @_operation.perform(@target)
      @vim.enterCommandMode()
      @resetState()
    else if @_operation.name == type
      @_operation.perform(@target, @defaultMotion())
      @resetState()
    else
      @_operation = @buildOperation(type)
  resetState: ->
    @enterState "idle"
    @_count = 1
    @_operation = @buildOperation(@defaultOperation())
  enterState: (state) ->
    @state = state
    @vim.stateChanged(@state) if @vim? and @vim.stateChanged?
  stateUpdated: ->
    @vim.stateUpdated(@state) if @vim? and @vim.stateUpdated?
  alias: (name) ->
    a = @aliases[name]
    @operation(a.operation)
    @motion(a.motion)
  aliases:
    'delete-character':
      motion: 'right'
      operation: 'delete'
    'delete-until-end-of-line':
      motion: 'end-of-line'
      operation: 'delete'
  motionEvents:
    left: "core:move-left"
    right: "core:move-right"
    up: "core:move-up"
    down: "core:move-down"
    line: "editor:move-line"
    'beginning-of-line': "editor:move-to-beginning-of-line"
    'end-of-line': "editor:move-to-end-of-line"
    'next-word': "editor:move-to-next-word"
    'previous-word': "editor:move-to-previous-word"
    'beginning-of-word': 'editor:move-to-beginning-of-word'
    'end-of-word': 'editor:move-to-end-of-word'
  operations:
    'move': ->
      @performMotion()
    'select': ->
      @performSelectMotion()
    'change': ->
      @performSelectMotion()
      @performEvent("core:delete")
      @vim.enterInsertMode()
    'delete': ->
      @performSelectMotion()
      @performEvent("core:delete")
