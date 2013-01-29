DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class FuzzyFinder extends DeferredAtomPackage

  loadEvents: [
    'fuzzy-finder:toggle-file-finder'
    'fuzzy-finder:toggle-buffer-finder'
    'fuzzy-finder:find-under-cursor'
  ]

  instanceClass: 'fuzzy-finder/src/fuzzy-finder-view'

  onLoadEvent: (event, instance) ->
    switch event.type
      when 'fuzzy-finder:toggle-file-finder'
        instance.toggleFileFinder()
      when 'fuzzy-finder:toggle-buffer-finder'
        instance.toggleBufferFinder()
      when 'fuzzy-finder:find-under-cursor'
        instance.findUnderCursor()
