# Using clipboard in renderer process is not safe on Linux.
module.exports =
  if process.platform is 'linux' and process.type is 'renderer'
    require('electron').remote.clipboard
  else
    require('electron').clipboard
