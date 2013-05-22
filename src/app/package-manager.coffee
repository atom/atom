{spawn} = require 'child_process'
roaster = require 'roaster'
async = require 'async'

### Internal ###

renderMarkdownInMetadata = (packages, callback) ->
  queue = async.queue (pack, callback) ->
    operations = []
    if pack.description
      operations.push (callback) ->
        roaster pack.description, {}, (error, html) ->
          pack.descriptionHtml = html
          callback()
    if pack.readme
      operations.push (callback) ->
        roaster pack.readme, {}, (error, html) ->
          pack.readmeHtml = html
          callback()
    async.waterfall(operations, callback)
  queue.push(pack) for pack in packages
  queue.drain = callback

getAvailable = (callback) ->
  apm = require.resolve '.bin/apm'
  apmProcess = spawn(apm, ['available', '--json'])
  chunks = []
  apmProcess.stdout.on 'data', (chunk) -> chunks.push(chunk)
  apmProcess.on 'close', (code) ->
    if code is 0
      try
        packages = JSON.parse(Buffer.concat(chunks).toString()) ? []
      catch error
        callback(error)
        return

      if packages.length > 0
        renderMarkdownInMetadata packages, -> callback(null, packages)
      else
        callback(null, packages)
    else
      callback(new Error("apm failed with code: #{code}"))

install = ({name, version}, callback) ->
  activateOnSuccess = !atom.isPackageDisabled(name)
  activateOnFailure = atom.isPackageActive(name)
  atom.deactivatePackage(name) if atom.isPackageActive(name)
  atom.unloadPackage(name) if atom.isPackageLoaded(name)

  apm = require.resolve '.bin/apm'
  apmProcess = spawn(apm, ['install', "#{name}@#{version}"])
  apmProcess.on 'close', (code) =>
    if code is 0
      atom.activatePackage(name) if activateOnSuccess
      callback()
    else
      actom.activatePackage(name) if activateOnFailure
      callback(new Error("Installing '#{name}' failed."))

uninstall = ({name}, callback) ->
  atom.deactivatePackage(name) if atom.isPackageActive(name)

  apm = require.resolve '.bin/apm'
  apmProcess = spawn(apm, ['uninstall', name])
  apmProcess.on 'close', (code) =>
    if code is 0
      atom.unloadPackage(name)
      callback()
    else
      callback(new Error("Uninstalling '#{name}' failed."))

module.exports = {renderMarkdownInMetadata, install, uninstall, getAvailable}
