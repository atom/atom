{Emitter} = require 'event-kit'
Gutter = require './gutter'

module.exports =
class GutterContainer
  constructor: (textEditor) ->
    @gutters = []
    @textEditor = textEditor
    @emitter = new Emitter

  scheduleComponentUpdate: ->
    @textEditor.scheduleComponentUpdate()

  destroy: ->
    # Create a copy, because `Gutter::destroy` removes the gutter from
    # GutterContainer's @gutters.
    guttersToDestroy = @gutters.slice(0)
    for gutter in guttersToDestroy
      gutter.destroy() if gutter.name isnt 'line-number'
    @gutters = []
    @emitter.dispose()

  addGutter: (options) ->
    options = options ? {}
    gutterName = options.name
    if gutterName is null
      throw new Error('A name is required to create a gutter.')
    if @gutterWithName(gutterName)
      throw new Error('Tried to create a gutter with a name that is already in use.')
    newGutter = new Gutter(this, options)

    inserted = false
    # Insert the gutter into the gutters array, sorted in ascending order by 'priority'.
    # This could be optimized, but there are unlikely to be many gutters.
    for i in [0...@gutters.length]
      if @gutters[i].priority >= newGutter.priority
        @gutters.splice(i, 0, newGutter)
        inserted = true
        break
    if not inserted
      @gutters.push newGutter
    @scheduleComponentUpdate()
    @emitter.emit 'did-add-gutter', newGutter
    return newGutter

  getGutters: ->
    @gutters.slice()

  gutterWithName: (name) ->
    for gutter in @gutters
      if gutter.name is name then return gutter
    null

  observeGutters: (callback) ->
    callback(gutter) for gutter in @getGutters()
    @onDidAddGutter callback

  onDidAddGutter: (callback) ->
    @emitter.on 'did-add-gutter', callback

  onDidRemoveGutter: (callback) ->
    @emitter.on 'did-remove-gutter', callback

  ###
  Section: Private Methods
  ###

  # Processes the destruction of the gutter. Throws an error if this gutter is
  # not within this gutterContainer.
  removeGutter: (gutter) ->
    index = @gutters.indexOf(gutter)
    if index > -1
      @gutters.splice(index, 1)
      @scheduleComponentUpdate()
      @emitter.emit 'did-remove-gutter', gutter.name
    else
      throw new Error 'The given gutter cannot be removed because it is not ' +
          'within this GutterContainer.'

  # The public interface is Gutter::decorateMarker or TextEditor::decorateMarker.
  addGutterDecoration: (gutter, marker, options) ->
    if gutter.name is 'line-number'
      options.type = 'line-number'
    else
      options.type = 'gutter'
    options.gutterName = gutter.name
    @textEditor.decorateMarker(marker, options)
