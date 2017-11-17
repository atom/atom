'use babel'

import path from 'path'
import Spawner from './spawner'

let powershellPath

if (process.env.SystemRoot) {
  let system32Path = path.join(process.env.SystemRoot, 'System32')
  powershellPath = path.join(system32Path, 'WindowsPowerShell', 'v1.0', 'powershell.exe')
} else {
  powershellPath = 'powershell.exe'
}

// Spawn powershell.exe and callback when it completes
let spawnPowershell = function (args, callback) {
  // Set encoding and execute the command, capture the output, and return it
  // via .NET's console in order to have consistent UTF-8 encoding.
  // See http://stackoverflow.com/questions/22349139/utf-8-output-from-powershell
  // to address https://github.com/atom/atom/issues/5063
  args[0] = `
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$output=${args[0]}
[Console]::WriteLine($output)
`
  args.unshift('-command')
  args.unshift('RemoteSigned')
  args.unshift('-ExecutionPolicy')
  args.unshift('-noprofile')
  return Spawner.spawn(powershellPath, args, callback)
}

// Get the user's PATH environment variable registry value.
//
// * `callback` The {Function} to call after registry operation is done.
//   It will be invoked with the same arguments provided by {Spawner.spawn}.
//
// Returns the user's path {String}.
export function getPath (callback) {
  return spawnPowershell(['[environment]::GetEnvironmentVariable(\'Path\',\'User\')'], function (error, stdout) {
    if (error != null) {
      return callback(error)
    }

    let pathOutput = stdout.replace(/^\s+|\s+$/g, '')
    return callback(null, pathOutput)
  })
}
