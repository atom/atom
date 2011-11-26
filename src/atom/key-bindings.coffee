app:
  'cmd-q': (app) -> app.quit()
  'cmd-n': (app) -> atom.native.newWindow()

window:
  'cmd-shift-I': (window) -> window.showConsole()
  'cmd-r': (window) -> window.reload()
  'cmd-w': (window) -> window.close()
  'cmd-o': (window) -> window.open()
  'cmd-O': (window) -> window.open window.prompt "Open URL:"
  'cmd-s': (window) -> window.save()
  'cmd-ctrl-s': ->
    if query = escape prompt 'Search the web:'
      window.open 'http://duckduckgo.com?q=' + query
  'cmd-shift-e': ->
    s = document.createElement 'script'
    s.type = 'text/javascript'
    document.body.appendChild s
    s.src = 'http://erkie.github.com/asteroids.min.js'

editor:
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
