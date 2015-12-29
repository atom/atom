class TestItem
  getUri: -> "test"

exports.activate = ->
  atom.workspace.addOpener -> new TestItem
