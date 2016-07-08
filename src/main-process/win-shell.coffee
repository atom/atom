Registry = require 'winreg'
Path = require 'path'

exeName = Path.basename(process.execPath)
appPath = "\"#{process.execPath}\""
appName = exeName.replace('atom', 'Atom').replace('beta', 'Beta').replace('.exe', '')

contextRegistrationParts = [
    {key: 'command', name: '', value: "#{appPath} \"%1\""},
    {name: '', value: "Open with #{appName}"},
    {name: 'Icon', value: "#{appPath}"}
]

# Register Atom as a file handler to be associated with file types
exports.isFileHandlerRegistered = (callback) ->
  isRegisteredToThisApp fileHandlerRegistration, callback

exports.registerFileHandler = (callback) ->
  addToRegistry fileHandlerRegistration, callback

exports.removeFileHandler = (callback) ->
  removeFromRegistry fileHandlerRegistration, callback

fileHandlerRegistration = {
  key: "\\Software\\Classes\\Applications\\#{exeName}",
  parts: [{key: 'shell\\open\\command', name: '', value: "#{appPath} \"%1\""}]
}

# Add "Open with Atom" to the File Explorer context menu for files
exports.isInContextFilesMenu = (callback) ->
  isRegisteredToThisApp contextFilesRegistration, callback

exports.addToContextFilesMenu = (callback) ->
  addToRegistry contextFilesRegistration, callback

exports.removeFromContextFilesMenu = (callback) ->
  removeFromRegistry contextFilesRegistration, callback

contextFilesRegistration = {
  key: "\\Software\\Classes\\*\\shell\\#{appName}",
  parts: contextRegistryParts
}

# Add "Open with Atom" to the File Explorer context menu for folders
exports.isInContextFoldersMenu = (callback) ->
  isRegisteredToThisApp contextFoldersRegistration, callback

exports.addToContextFoldersMenu = (callback) ->
  addToRegistry contextFoldersRegistration, ->
    addToRegistry contexBackgroundRegistration, callback

exports.removeFromContextFoldersMenu = (callback) ->
  removeFromRegistry contextFoldersRegistration, ->
    removeFromRegistry contextBackgroundRegistration, callback

contextFoldersRegistration = {
  key: "\\Software\\Classes\\Directory\\shell\\#{appName}", # Right-click folder
  parts: contextRegistryParts
}

contextFoldersBackgroundRegistration = { # Right-click the background of a folder
  key: "\\Software\\Classes\\Directory\\background\\shell\\#{appName}",
  parts: JSON.parse(JSON.stringify(contextRegistryParts).replace('%1', '%V'))
}

# Installing Atom should register the file handler only
exports.installingAtom = (callback) ->
  registerFileHandler callback

# Upgrading Atom should upgrade any existing registry keys for this exeName
exports.upgradingAtom = (callback) ->
  updateRegistryIfSameExeName fileHandlerRegistration, ->
    updateRegistryIfSameExeName contextFileRegistration, ->
      updateRegistryIfSameExeName contextFolderRegistration, ->
        updateRegistryIfSameExeName contextBackgroundRegistration, callback

# Uninstalling Atom should remove any registry keys pointing to this appPath
exports.uninstallingAtom = (callback) ->
  removeFromRegistryIfUs fileHandlerRegistration, ->
    removeFromRegistryIfUs contextFileRegistration, ->
      removeFromRegistryIfUs contextFolderRegistration, ->
        removeFromRegistryIfUs contextBackgroundRegistration, callback

getRegistryFirstValue = (registration, callback) ->
  primaryPart = registration.parts[0]
  new Registry({hive: 'HKCU', key: "#{registration.key}\\#{primaryPart.key}"})
    .get primaryPart.name, callback

isRegisteredToThisApp = (registration, callback) ->
  getRegistryFirstValue registration, (err, val) ->
    callback(not err? and val.value is registration.parts[0].value)

addToRegistry = (registration, callback) ->
  doneCount = registration.parts.length
  registration.parts.forEach((part) ->
    reg = new Registry({hive: 'HKCU', key: if part.key? then "#{registration.key}\\#{part.key}" else registration.key})
    reg.create( -> reg.set part.name, Registry.REG_SZ, part.value, -> callback() if doneCount-- is 0)
  )

updateRegistryIfSameExeName = (registration, callback) ->
  getRegistryFirstValue registration, (err, val) ->
    if not err? and val.value.endsWith(exeName)
      addToRegistry registration, callback
    else
      callback(err, val)

removeFromRegistry = (registration, callback) ->
  new Registry({hive: 'HKCU', key: registration.key}).destroy callback

removeFromRegistryIfThisApp = (registration, callback) ->
  isRegisteredToThisApp registration, (isThisApp) ->
    if isThisApp
      removeFromRegistry registration, callback
    else
      callback(isThisApp)
