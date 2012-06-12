module.exports =
class Native
  @alert: (args...) -> $native.alert(args...)

  @saveDialog: (args...) -> $native.saveDialog(args...)

  @moveToTrash: (args...) -> $native.moveToTrash(args...)
