module.exports =
class Native
  @alert: (args...) -> $native.alert(args...)

  @moveToTrash: (args...) -> $native.moveToTrash(args...)