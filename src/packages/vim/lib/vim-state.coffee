
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
  performMotion: (select) ->
    if select? && select
      @motion.performSelect(@target)
    else
      @motion.perform(@target)

module.exports =
class VimState
  constructor: (@target, @vim) ->
    @resetState()
    for m,event of @motionEvents
      do (m, event) =>
        @target.command "vim:motion-#{m}", => @motion(m)
    for o,callback of @operations
      do(o) =>
        @target.command "vim:operation-#{o}", => @operation(o)
  motion: (type) ->
    event = @motionEvents[type]
    m = new VimMotion(type, event, @_count)
    @_operation.perform(@target, m)
    @resetState()
  defaultMotion: () ->
    new VimMotion('line', @motionEvents['line'], 1)
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @enterState "count"
    @_count = @_count * 10 + n if n?
    @stateUpdated()
    @_count
  count: (n) ->
    @_count = n if n?
    @_count
  buildOperation: (type) ->
    type = 'move' if !@operations[type]?
    new VimOperation(type, @operations[type], @vim)
  operation: (type) ->
    if @_operation.name != type
      @_operation = @buildOperation(type)
    else
      @_operation.perform(@target, @defaultMotion())
      @resetState()
  resetState: ->
    @enterState "idle"
    @_count = 1
    @_operation = @buildOperation('move')
  enterState: (state) ->
    @state = state
    @vim.stateChanged(@state) if @vim? and @vim.stateChanged?
  stateUpdated: ->
    @vim.stateUpdated(@state) if @vim? and @vim.stateUpdated?

  motionEvents:
    left: "core:move-left"
    right: "core:move-right"
    up: "core:move-up"
    down: "core:move-down"
    line: "editor:move-line"
    'move-to-beginning-of-line': "editor:move-to-beginning-of-line"
    'move-to-end-of-line': "editor:move-to-end-of-line"
  operations:
    'move': ->
      @performMotion()
    'change': ->
      @performMotion(true)
      @performEvent("core:delete")
      @vim.enterInsertMode()
    'delete': ->
      @performMotion(true)
      @performEvent("core:delete")
