app:
  'cmd-q': (app) -> app.quit()
  'cmd-j': (app) -> console.log "OMG YOU TOUCHED THE LETTER J!"

window:
  'cmd-shift-i': (window) -> window.showConsole()
  'cmd-w': (window) -> window.close()
  'cmd-o': (window) -> window.open()
  'cmd-r': (window) -> window.reload()

editor:
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
