fsUtils = require 'fs-utils'
path = require 'path'
Theme = require 'theme'

# Internal: Represents a theme that Atom can use.
module.exports =
class AtomTheme extends Theme

  # Given a path, this loads it as a stylesheet.
  #
  # stylesheetPath - A {String} to a stylesheet
  loadStylesheet: (stylesheetPath)->
    @stylesheets[stylesheetPath] = window.loadStylesheet(stylesheetPath)

  # Loads the stylesheets found in a `package.cson` file.
  load: ->
    if path.extname(@path) in ['.css', '.less']
      @loadStylesheet(@path)
    else
      metadataPath = fsUtils.resolveExtension(fsUtils.join(@path, 'package'), ['cson', 'json'])
      if fsUtils.isFile(metadataPath)
        stylesheetNames = fsUtils.readObject(metadataPath)?.stylesheets
        if stylesheetNames
          for name in stylesheetNames
            filename = fsUtils.resolveExtension(fsUtils.join(@path, name), ['.css', '.less', ''])
            @loadStylesheet(filename)
      else
        @loadStylesheet(stylesheetPath) for stylesheetPath in fsUtils.list(@path, ['.css', '.less'])

    super
