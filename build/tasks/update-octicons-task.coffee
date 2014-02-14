path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'update-octicons', 'Update octicon font and LESS variables', ->
    pathToOcticons = path.resolve('..', 'octicons')
    if grunt.file.isDir(pathToOcticons)
      # Copy font-file
      fontSrc = path.join(pathToOcticons, 'octicons', 'octicons.woff')
      fontDest = path.resolve('static', 'octicons.woff')
      grunt.file.copy(fontSrc, fontDest)

      # Update Octicon UTF codes
      glyphsSrc = path.join(pathToOcticons, 'data', 'glyphs.yml')
      output = []
      for {css, code} in grunt.file.readYAML(glyphsSrc)
        output.push "@#{css}: \"\\#{code}\";"

      octiconUtfDest = path.resolve('static', 'variables', 'octicon-utf-codes.less')
      grunt.file.write(octiconUtfDest, "#{output.join('\n')}\n")
    else
      grunt.log.error("octicons repo must be cloned to #{pathToOcticons}")
      false
