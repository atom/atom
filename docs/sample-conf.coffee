# ~/.atom/settings.coffee
# ----------------------------

editor:
  tabSize: 2
  spaces: true

# ~/.atom/keybindings.coffee

app:
  "cmd-q": (app) -> app.quit()
  "cmd-q": "quit" # optional way?
editor:
  "ctrl-p": (editor) -> editor.moveUp()
  "ctrl-a": (editor) ->
    position = editor.cursorPosition()
    position.column = 0
    editor.setCursorPosition(position)
tree:
  "cmd-ctrl-n": (tree) -> tree.toggle()
window:
    'Command-O'       : @open
    'Command-Ctrl-K'  : @showConsole

