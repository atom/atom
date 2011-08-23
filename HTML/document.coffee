# Fires these events:
#   - opened
#   - saved
#   - created
class Document
  path: null
  text: null
  listeners: []
  
  constructor: (@path, @text) ->
  
  name: ->
    _.last @path.split '/' if @path
  
  save: ->
    trigger 'saved'
    
  open = ->
    trigger 'opened'

  on: (message, listener) ->
    @listeners.push listener

  trigger: (message, args...) ->
    _.each @listeners, (listener) ->
      listener.call args...