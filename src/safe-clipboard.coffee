# Using clipboard in renderer process is not safe on Linux.
module.exports =
  if process.platform is 'linux' and process.type is 'renderer'
    require('remote').require('clipboard')
  else
    require('clipboard')
