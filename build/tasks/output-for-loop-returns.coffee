path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'output-for-loop-returns', 'Log methods that end with a for loop', ->
    appDir = grunt.config.get('atom.appDir')

    jsPaths = []
    grunt.file.recurse path.join(appDir, 'src'), (absolutePath, rootPath, relativePath, fileName) ->
      jsPaths.push(absolutePath) if path.extname(fileName) is '.js'

    jsPaths.forEach (jsPath) ->
      js = grunt.file.read(jsPath)
      method = null
      for line, index in js.split('\n')
        [match, className, methodName] = /^\s*([a-zA-Z]+)\.(?:prototype\.)?([a-zA-Z]+)\s*=\s*function\(/.exec(line) ? []
        if className and methodName
          method = "#{className}::#{methodName}"
        else
          [match, ctorName] = /^\s*function\s+([a-zA-Z]+)\(/.exec(line) ? []

        if /^\s*return\s+_results;\s*$/.test(line)
          console.log(method ? "#{path.basename(jsPath)}:#{index}")
