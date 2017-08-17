Registry = require 'winreg'
Path = require 'path'

getAppVersion = ->
  if process.type is 'renderer'
    return atom.getVersion()
  else
    electron = require 'electron'
    return electron.app.getVersion()

exeName = Path.basename(process.execPath)
appPath = "\"#{process.execPath}\""
isBeta = getAppVersion().includes('beta')
appName = exeName.replace('atom', (if isBeta then 'Atom Beta' else 'Atom' )).replace('.exe', '')

class ShellOption
  constructor: (key, parts) ->
    @key = key
    @parts = parts

  isRegistered: (callback) =>
    new Registry({hive: 'HKCU', key: "#{@key}\\#{@parts[0].key}"})
      .get @parts[0].name, (err, val) =>
        callback(not err? and val? and val.value is @parts[0].value)

  register: (callback) =>
    doneCount = @parts.length
    @parts.forEach (part) =>
      reg = new Registry({hive: 'HKCU', key: if part.key? then "#{@key}\\#{part.key}" else @key})
      reg.create( -> reg.set part.name, Registry.REG_SZ, part.value, -> callback() if --doneCount is 0)

  deregister: (callback) =>
    @isRegistered (isRegistered) =>
      if isRegistered
        new Registry({hive: 'HKCU', key: @key}).destroy -> callback null, true
      else
        callback null, false

  update: (callback) =>
    new Registry({hive: 'HKCU', key: "#{@key}\\#{@parts[0].key}"})
      .get @parts[0].name, (err, val) =>
        if err? or not val?
          callback(err)
        else
          @register callback

exports.appName = appName

exports.fileHandler = new ShellOption("\\Software\\Classes\\Applications\\#{exeName}",
  [
    {key: 'shell\\open\\command', name: '', value: "#{appPath} \"%1\""},
    {key: 'shell\\open', name: 'FriendlyAppName', value: "#{appName}"}
  ]
)

contextParts = [
    {key: 'command', name: '', value: "#{appPath} \"%1\""},
    {name: '', value: "Open with #{appName}"},
    {name: 'Icon', value: "#{appPath}"}
]

exports.fileContextMenu = new ShellOption("\\Software\\Classes\\*\\shell\\#{appName}", contextParts)

exports.folderContextMenu = new ShellOption("\\Software\\Classes\\Directory\\shell\\#{appName}", contextParts)

exports.folderBackgroundContextMenu = new ShellOption("\\Software\\Classes\\Directory\\background\\shell\\#{appName}",
  JSON.parse(JSON.stringify(contextParts).replace('%1', '%V'))
)
