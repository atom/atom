{PathReplacer} = require 'scandal'

module.exports = (filePaths, regexSource, regexFlags, replacementText) ->
  callback = @async()

  replacer = new PathReplacer()
  regex = new RegExp(regexSource, regexFlags)

  replacer.on 'file-error', ({code, path, message}) ->
    emit('replace:file-error', {code, path, message})

  replacer.on 'path-replaced', (result) ->
    emit('replace:path-replaced', result)

  replacer.replacePaths(regex, replacementText, filePaths, -> callback())
