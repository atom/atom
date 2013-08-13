BufferedProcess = require 'buffered-process'
path = require 'path'

# Like BufferedProcess, but accepts a node script instead of an executable,
# on Unix which allows running scripts and executables, this seems unnecessary,
# but on Windows we have to separate scripts from executables since it doesn't
# support shebang strings.
module.exports =
class BufferedNodeProcess extends BufferedProcess
  constructor: ({command, args, options, stdout, stderr, exit}) ->
    args = ['--atom-child_process-fork', command].concat(args)
    node =
      if process.platform is 'darwin'
        # On OS X we use the helper process to run script, because it doesn't
        # create an icon on the Dock.
        path.resolve(process.resourcesPath, '..', 'Frameworks',
                     'Atom Helper.app', 'Contents', 'MacOS', 'Atom Helper')
      else
        process.execPath

    super({command: node, args, options, stdout, stderr, exit})
