{$, EditorView, ScrollView} = require 'atom'

module.exports =
class IndicoView extends ScrollView
  @content: ->
    @div class: 'indico overlay from-top', =>
      @div =>
        @subview 'questionField', new EditorView(mini:true, placeholderText: 'Enter some text pyon pyon')
      @div "The Sssss package is Alive! It's ALIVE!", class: "message", =>
      @div "The Sssss package is Alive! It's ALIVE!", class: "message", =>
      @div "The Sssss package is Alive! It's ALIVE!", class: "message", =>
      @div "The Sssss package is Alive! It's ALIVE!", class: "message"
  initialize: (serializeState) ->
    @handleEvents()
    atom.workspaceView.command "indico:toggle", => @toggle()
  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    console.log "IndicoView was toggled!"
    if @hasParent()
      @detach()
    else
      atom.workspaceView.append(this)

  handleEvents: ->
    @questionField.on 'core:confirm', => @butts()

  butts: ->
    text = @questionField.getText()
    $('.message').text(text)
