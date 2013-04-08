fsUtils = require 'fs-utils'
Theme = require 'theme'
CSON = require 'cson'

module.exports =
class AtomTheme extends Theme

  loadStylesheet: (stylesheetPath)->
    @stylesheets[stylesheetPath] = window.loadStylesheet(stylesheetPath)

  load: ->
    if fsUtils.extension(@path) in ['.css', '.less']
      @loadStylesheet(@path)
    else
      metadataPath = fsUtils.resolveExtension(fsUtils.join(@path, 'package'), ['cson', 'json'])
      if fsUtils.isFile(metadataPath)
        stylesheetNames = CSON.readObject(metadataPath)?.stylesheets
        if stylesheetNames
          for name in stylesheetNames
            filename = fsUtils.resolveExtension(fsUtils.join(@path, name), ['.css', '.less', ''])
            @loadStylesheet(filename)
      else
        @loadStylesheet(stylesheetPath) for stylesheetPath in fsUtils.list(@path, ['.css', '.less'])

    super
