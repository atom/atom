app:
  'cmd-q': (app) -> app.quit()
  'cmd-n': (app) -> atom.native.newWindow()

window:
  'cmd-shift-I': (window) -> window.showConsole()
  'cmd-r': (window) -> window.reload()
  'cmd-o': (window) -> window.open()
  'cmd-s': (window) -> window.save()

resource:
  'cmd-shift-d': -> console.log 'derp'

editor:
  'cmd-w': 'close'
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
