module.exports =
class Native
  @alert: (args...) -> $native.alert(args...)

  @saveDialog: (args...) -> $native.saveDialog(args...)

  @reload: -> $native.reload()

  @moveToTrash: (args...) -> $native.moveToTrash(args...)
