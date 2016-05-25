path = require 'path'
Spawner = require './spawner'

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  regPath = path.join(system32Path, 'reg.exe')
else
  regPath = 'reg.exe'

# Registry keys used for context menu
fileKeyPath = 'HKCU\\Software\\Classes\\*\\shell\\Atom'
directoryKeyPath = 'HKCU\\Software\\Classes\\directory\\shell\\Atom'
backgroundKeyPath = 'HKCU\\Software\\Classes\\directory\\background\\shell\\Atom'
applicationsKeyPath = 'HKCU\\Software\\Classes\\Applications\\atom.exe'

# Spawn reg.exe and callback when it completes
spawnReg = (args, callback) ->
  Spawner.spawn(regPath, args, callback)

# Install the Open with Atom explorer context menu items via the registry.
#
# * `callback` The {Function} to call after registry operation is done.
#   It will be invoked with the same arguments provided by {Spawner.spawn}.
#
# Returns `undefined`.
exports.installContextMenu = (callback) ->
  addToRegistry = (args, callback) ->
    args.unshift('add')
    args.push('/f')
    spawnReg(args, callback)

  installFileHandler = (callback) ->
    args = ["#{applicationsKeyPath}\\shell\\open\\command", '/ve', '/d', "\"#{process.execPath}\" \"%1\""]
    addToRegistry(args, callback)

  installMenu = (keyPath, arg, callback) ->
    args = [keyPath, '/ve', '/d', 'Open with Atom']
    addToRegistry args, ->
      args = [keyPath, '/v', 'Icon', '/d', "\"#{process.execPath}\""]
      addToRegistry args, ->
        args = ["#{keyPath}\\command", '/ve', '/d', "\"#{process.execPath}\" \"#{arg}\""]
        addToRegistry(args, callback)

  installMenu fileKeyPath, '%1', ->
    installMenu directoryKeyPath, '%1', ->
      installMenu backgroundKeyPath, '%V', ->
        installFileHandler(callback)

# Uninstall the Open with Atom explorer context menu items via the registry.
#
# * `callback` The {Function} to call after registry operation is done.
#   It will be invoked with the same arguments provided by {Spawner.spawn}.
#
# Returns `undefined`.
exports.uninstallContextMenu = (callback) ->
  deleteFromRegistry = (keyPath, callback) ->
    spawnReg(['delete', keyPath, '/f'], callback)

  deleteFromRegistry fileKeyPath, ->
    deleteFromRegistry directoryKeyPath, ->
      deleteFromRegistry backgroundKeyPath, ->
        deleteFromRegistry(applicationsKeyPath, callback)
