class Foo
  atom.deserializers.add(this)
  @deserialize: ({data}) -> new Foo(data)
  constructor: (@data) ->

module.exports =
  activateCallCount: 0
  activationEventCallCount: 0

  activate: ->
    @activateCallCount++
    atom.workspaceView.getActiveView()?.command 'activation-event', =>
      @activationEventCallCount++
