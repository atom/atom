app:
  'cmd-q': (app) -> app.quit()
  'cmd-j': (app) -> console.log "OMG YOU TOUCHED THE LETTER J!"

window:
  'cmd-shift-i': (window) -> window.showConsole()
  'cmd-o': (window) -> window.open()

editor:
  'cmd-s': 'save'
  'cmd-shift-s': 'saveAs'
  'cmd-c': 'copy'
  'cmd-x': 'cut'
  'cmd-r': 'eval'
  'cmd-/': 'toggleComment'
  'cmd-[': 'outdent'
  'cmd-]': 'indent'
  'alt-f': 'forwardWord'
  'alt-b': 'backWord'
  'alt-d': 'deleteWord'
  'alt-shift-,': 'home'
  'alt-shift-.': 'end'
  'ctrl-l': 'consolelog'
