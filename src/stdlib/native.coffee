module.exports =
class Native
  @reload: -> $native.reload()

  @moveToTrash: (args...) -> $native.moveToTrash(args...)
