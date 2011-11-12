app:
  'cmd-q': (app) -> app.quit()

window:
  'cmd-shift-I': (window) -> window.showConsole()
  'cmd-r': (window) -> window.reload()
  'cmd-o': (window) -> window.open()

resource:
  'cmd-shift-d': -> console.log 'derp'

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
