import {PathReplacer} from 'scandal'

export default function (filePaths, regexSource, regexFlags, replacementText) {
  let callback = this.async()

  let replacer = new PathReplacer()
  let regex = new RegExp(regexSource, regexFlags)

  replacer.on('file-error', ({code, path, message}) => {
    this.emit('replace:file-error', {code, path, message})
  })

  replacer.on('path-replaced', (result) => {
    this.emit('replace:path-replaced', result)
  })

  return replacer.replacePaths(regex, replacementText, filePaths, () => callback())
}
