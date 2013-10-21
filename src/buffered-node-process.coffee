BufferedProcess = require './buffered-process'
path = require 'path'

# Public: Like {BufferedProcess}, but accepts a Node script instead of an
# executable.
#
# This may seem unnecessary but on Windows we have to have separate executables
# for each script without this since Windows doesn't support shebang strings.
module.exports =
class BufferedNodeProcess extends BufferedProcess
  # Executes the given Node script.
  #
  # * options
  #    + command:
  #      The path to the Javascript script to execute.
  #    + args:
  #      The array of arguments to pass to the script (optional).
  #    + options:
  #      The options Object to pass to Node's `ChildProcess.spawn` (optional).
  #    + stdout:
  #      The callback that receives a single argument which contains the
  #      standard output of the script. The callback is called as data is
  #      received but it's buffered to ensure only complete lines are passed
  #      until the source stream closes. After the source stream has closed
  #      all remaining data is sent in a final call (optional).
  #    + stderr:
  #      The callback that receives a single argument which contains the
  #      standard error of the script. The callback is called as data is
  #      received but it's buffered to ensure only complete lines are passed
  #      until the source stream closes. After the source stream has closed
  #      all remaining data is sent in a final call (optional).
  #    + exit:
  #      The callback which receives a single argument containing the exit
  #      status (optional).
  constructor: ({command, args, options, stdout, stderr, exit}) ->
    node =
      if process.platform is 'darwin'
        # Use a helper to prevent an icon from appearing on the Dock
        path.resolve(process.resourcesPath, '..', 'Frameworks',
                     'Atom Helper.app', 'Contents', 'MacOS', 'Atom Helper')
      else
        process.execPath

    options ?= {}
    options.env ?= Object.create(process.env)
    options.env['ATOM_SHELL_INTERNAL_RUN_AS_NODE'] = 1

    args.unshift(command)
    super({command: node, args, options, stdout, stderr, exit})
