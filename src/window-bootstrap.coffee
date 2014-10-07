# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

ModuleCache = require('./module-cache')
ModuleCache.add(JSON.parse(decodeURIComponent(location.search.substr(14))).resourcePath)
ModuleCache.register()

require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()
window.atom.loadTime = Date.now() - startTime
console.log "Window load time: #{atom.getWindowLoadTime()}ms"

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('atom-workspace').focus()), 0
window.addEventListener('focus', windowFocused)
