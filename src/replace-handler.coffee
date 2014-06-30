{PathReplacer} = require 'scandal'

module.exports = (filePaths, regexSource, regexFlags, replacementText) ->
  callback = @async()

  replacer = new PathReplacer()
  regex = new RegExp(regexSource, regexFlags)

  replacer.on 'file-error', (e) ->
    error = {code: e.code, path: e.path, message: e.message}
    emit('replace:file-error', error)

  replacer.on 'path-replaced', (result) ->
    emit('replace:path-replaced', result)

  replacer.replacePaths(regex, replacementText, filePaths, -> callback())
