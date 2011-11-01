app:
  'cmd-q': (app) -> app.quit()
  'cmd-o': (app) -> app.open()

window:
  'cmd-shift-i': (window) -> window.showConsole()
  'cmd-r': (window) -> window.reload()

editor:
  'cmd-w': 'close'
  'cmd-s': 'save'
  'cmd-shift-s': 'saveAs'
  'cmd-c': 'copy'
  'cmd-x': 'cut'
  'cmd-/': 'toggleComment'
  'cmd-[': 'outdent'
  'cmd-]': 'indent'
  'alt-f': 'forwardWord'
  'alt-b': 'backWord'
  'alt-d': 'deleteWord'
  'alt-shift-,': 'home'
  'alt-shift-.': 'end'
  'ctrl-l': 'consolelog'
