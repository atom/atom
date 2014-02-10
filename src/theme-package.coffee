AtomPackage = require './atom-package'

### Internal: Loads and resolves packages. ###

module.exports =
class ThemePackage extends AtomPackage

  getType: -> 'theme'

  getStylesheetType: -> 'theme'

  enable: ->
    atom.config.unshiftAtKeyPath('core.themes', @metadata.name)

  disable: ->
    atom.config.removeAtKeyPath('core.themes', @metadata.name)
