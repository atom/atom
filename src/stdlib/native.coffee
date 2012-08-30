module.exports =
class Native
  @saveDialog: (args...) -> $native.saveDialog(args...)

  @reload: -> $native.reload()

  @moveToTrash: (args...) -> $native.moveToTrash(args...)
