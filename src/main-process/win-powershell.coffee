path = require 'path'
Spawner = require './spawner'

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  powershellPath = path.join(system32Path, 'WindowsPowerShell', 'v1.0', 'powershell.exe')
else
  powershellPath = 'powershell.exe'

# Spawn powershell.exe and callback when it completes
spawnPowershell = (args, callback) ->
  # Set encoding and execute the command, capture the output, and return it
  # via .NET's console in order to have consistent UTF-8 encoding.
  # See http://stackoverflow.com/questions/22349139/utf-8-output-from-powershell
  # to address https://github.com/atom/atom/issues/5063
  args[0] = """
    [Console]::OutputEncoding=[System.Text.Encoding]::UTF8
    $output=#{args[0]}
    [Console]::WriteLine($output)
  """
  args.unshift('-command')
  args.unshift('RemoteSigned')
  args.unshift('-ExecutionPolicy')
  args.unshift('-noprofile')
  Spawner.spawn(powershellPath, args, callback)

# Get the user's PATH environment variable registry value.
#
# * `callback` The {Function} to call after registry operation is done.
#   It will be invoked with the same arguments provided by {Spawner.spawn}.
#
# Returns the user's path {String}.
exports.getPath = (callback) ->
  spawnPowershell ['[environment]::GetEnvironmentVariable(\'Path\',\'User\')'], (error, stdout) ->
    if error?
      return callback(error)

    pathOutput = stdout.replace(/^\s+|\s+$/g, '')
    callback(null, pathOutput)
