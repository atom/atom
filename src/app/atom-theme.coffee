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
      if fs.isFile(metadataPath)
        stylesheetNames = fs.readObject(metadataPath)?.stylesheets
        if stylesheetNames
          @loadStylesheet(fs.join(@path, name)) for name in stylesheetNames
      else
        @loadStylesheet(stylesheetPath) for stylesheetPath in fs.list(@path, ['.css'])

    super
