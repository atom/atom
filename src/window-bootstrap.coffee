# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()
endTime = Date.now()
atom.loadTimeStart = startTime
atom.loadTimeEnd = endTime
atom.loadTime = endTime - startTime
console.log "Window load time: #{atom.getWindowLoadTime()}ms"

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('.workspace').focus()), 0
window.addEventListener('focus', windowFocused)
