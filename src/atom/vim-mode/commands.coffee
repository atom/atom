class Command
  isComplete: -> true

class DeleteChar extends Command
  execute: (editor) ->
    editor.deleteChar()

module.exports = { DeleteChar }

