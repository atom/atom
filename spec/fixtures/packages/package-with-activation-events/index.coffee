class Foo
  registerDeserializer(this)
  @deserialize: ({data}) -> new Foo(data)
  constructor: (@data) ->

module.exports =
  activateCallCount: 0
  activationEventCallCount: 0

  activate: ->
    @activateCallCount++
    rootView.getActiveView()?.command 'activation-event', =>
      @activationEventCallCount++
