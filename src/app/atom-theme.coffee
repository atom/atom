fs = require 'fs'
Theme = require 'theme'

module.exports =
class AtomTheme extends Theme

  loadStylesheet: (stylesheetPath)->
    @stylesheets[stylesheetPath] = fs.read(stylesheetPath)

  load: ->
    if fs.extension(@path) is '.css'
      @loadStylesheet(@path)
    else
      metadataPath = fs.resolveExtension(fs.join(@path, 'package'), ['cson', 'json'])
      stylesheetNames = fs.readObject(metadataPath).stylesheets
      @loadStylesheet(fs.join(@path, name)) for name in stylesheetNames
    super
