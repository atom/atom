BufferedProcess = require 'buffered-process'
path = require 'path'

# Private: Like BufferedProcess, but accepts a node script instead of an
# executable, on Unix which allows running scripts and executables, this seems
# unnecessary, but on Windows we have to separate scripts from executables since
# it doesn't support shebang strings.
module.exports =
class BufferedNodeProcess extends BufferedProcess
  constructor: ({command, args, options, stdout, stderr, exit}) ->
    node =
      if process.platform is 'darwin'
        # On OS X we use the helper process to run script, because it doesn't
        # create an icon on the Dock.
        path.resolve(process.resourcesPath, '..', 'Frameworks',
                     'Atom Helper.app', 'Contents', 'MacOS', 'Atom Helper')
      else
        process.execPath

    # Tell atom-shell to run like upstream node.
    options ?= {}
    options.env ?= Object.create(process.env)
    options.env['ATOM_SHELL_INTERNAL_RUN_AS_NODE'] = 1

    args.unshift(command)
    super({command: node, args, options, stdout, stderr, exit})
