Spawner = require './spawner'

# Registry keys used for context menu
fileKeyPath = 'HKCU\\Software\\Classes\\*\\shell\\Atom'
directoryKeyPath = 'HKCU\\Software\\Classes\\directory\\shell\\Atom'
backgroundKeyPath = 'HKCU\\Software\\Classes\\directory\\background\\shell\\Atom'

# Registry keys used for environment variables
environmentKeyPath = 'HKCU\\Environment'

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  regPath = path.join(system32Path, 'reg.exe')
else
  regPath = 'reg.exe'

# Spawn reg.exe and callback when it completes
spawnReg = (args, callback) ->
  Spawner.spawn(regPath, args, callback)

isAscii = (text) ->
  index = 0
  while index < text.length
    return false if text.charCodeAt(index) > 127
    index++
  true

# Install the Open with Atom explorer context menu items via the registry.
exports.installContextMenu = (callback) ->
  addToRegistry = (args, callback) ->
    args.unshift('add')
    args.push('/f')
    spawnReg(args, callback)

  installMenu = (keyPath, arg, callback) ->
    args = [keyPath, '/ve', '/d', 'Open with Atom']
    addToRegistry args, ->
      args = [keyPath, '/v', 'Icon', '/d', process.execPath]
      addToRegistry args, ->
        args = ["#{keyPath}\\command", '/ve', '/d', "#{process.execPath} \"#{arg}\""]
        addToRegistry(args, callback)

  installMenu fileKeyPath, '%1', ->
    installMenu directoryKeyPath, '%1', ->
      installMenu(backgroundKeyPath, '%V', callback)

# Uninstall the Open with Atom explorer context menu items via the registry.
exports.uninstallContextMenu = (callback) ->
  deleteFromRegistry = (keyPath, callback) ->
    spawnReg(['delete', keyPath, '/f'], callback)

  deleteFromRegistry fileKeyPath, ->
    deleteFromRegistry directoryKeyPath, ->
      deleteFromRegistry(backgroundKeyPath, callback)

# Get the user's PATH environment variable registry value.
exports.getPath = (callback) ->
  spawnReg ['query', environmentKeyPath, '/v', 'Path'], (error, stdout) ->
    if error?
      if error.code is 1
        # FIXME Don't overwrite path when reading value is disabled
        # https://github.com/atom/atom/issues/5092
        if stdout.indexOf('ERROR: Registry editing has been disabled by your administrator.') isnt -1
          return callback(error)

        # The query failed so the Path does not exist yet in the registry
        return callback(null, '')
      else
        return callback(error)

    # Registry query output is in the form:
    #
    # HKEY_CURRENT_USER\Environment
    #     Path    REG_SZ    C:\a\folder\on\the\path;C\another\folder
    #

    lines = stdout.split(/[\r\n]+/).filter (line) -> line
    segments = lines[lines.length - 1]?.split('    ')
    if segments[1] is 'Path' and segments.length >= 3
      pathEnv = segments?[3..].join('    ')
      if isAscii(pathEnv)
        callback(null, pathEnv)
      else
        # FIXME Don't corrupt non-ASCII PATH values
        # https://github.com/atom/atom/issues/5063
        callback(new Error('PATH contains non-ASCII values'))
    else
      callback(new Error('Registry query for PATH failed'))
