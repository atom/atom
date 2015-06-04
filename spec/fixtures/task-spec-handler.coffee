module.exports = ->
  emit("some-event", 1, 2, 3)
  @emit("some-other-event", 4, 5, 6)
  'hello'
