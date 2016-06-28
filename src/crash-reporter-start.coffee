module.exports = (extra) ->
  # Breakpad on Mac OS X must be running on UI and non-UI processes
  # Crashpad on Windows and Linux should only be running on non-UI process
  return if process.type is 'renderer' and process.platform isnt 'darwin'

  {crashReporter} = require 'electron'

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'http://54.249.141.255:1127/post'
    extra: extra
  })
