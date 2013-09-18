_ = require './underscore-extensions'
child_process = require 'child_process'
EventEmitter = require './event-emitter'

# Public: Run a node script in a separate process.
#
# Used by the fuzzy-finder.
#
# ## Events
#
# * task:log - Emitted when console.log is called within the task.
# * task:warn - Emitted when console.warn is called within the task.
# * task:error - Emitted when console.error is called within the task.
# * task:complete - Emitted when the task has succeeded or failed.
module.exports =
class Task
  _.extend @prototype, EventEmitter

  # Public: A helper method to easily launch and run a task once.
  #
  # * taskPath:
  #   The path to the Coffeescript/Javascript file which exports a single
  #   function to execute.
  # * args:
  #   The Array of arguments to pass to the exported function.
  @once: (taskPath, args...) ->
    task = new Task(taskPath)
    task.one 'task:completed', -> task.terminate()
    task.start(args...)
    task

  # Public: Called upon task completion.
  #
  # It receives the same arguments that were passed to the task.
  #
  # If subclassed, this is intended to be overridden. However if {.start}
  # receives a completion callback, this is overridden.
  callback: null

  # Public: Creates a task.
  #
  # * taskPath:
  #   The path to the Coffeescript/Javascript file that exports a single
  #   function to execute.
  constructor: (taskPath) ->
    coffeeScriptRequire = "require('#{require.resolve('coffee-script')}');"
    coffeeCacheRequire = "require('#{require.resolve('./coffee-cache')}');"
    taskBootstrapRequire = "require('#{require.resolve('task-bootstrap')}');"
    bootstrap = """
      #{coffeeScriptRequire}
      #{coffeeCacheRequire}
      Object.defineProperty(require.extensions, '.coffee', {
        writable: false,
        value: require.extensions['.coffee']
      });
      #{taskBootstrapRequire}
    """

    taskPath = require.resolve(taskPath)

    env = _.extend({}, process.env, {taskPath, userAgent: navigator.userAgent})
    args = [bootstrap, '--harmony_collections']
    @childProcess = child_process.fork '--eval', args, {env, cwd: __dirname}

    @on "task:log", -> console.log(arguments...)
    @on "task:warn", -> console.warn(arguments...)
    @on "task:error", -> console.error(arguments...)
    @on "task:completed", (args...) => @callback?(args...)

    @handleEvents()

  # Private: Routes messages from the child to the appropriate event.
  handleEvents: ->
    @childProcess.removeAllListeners()
    @childProcess.on 'message', ({event, args}) =>
      @trigger(event, args...)

  # Public: Starts the task.
  #
  # * args:
  #   The Array of arguments to pass to the function exported by the script. If
  #   the last argument is a function, its removed from the array and called
  #   upon completion (and replaces the complete function on the task instance).
  start: (args...) ->
    throw new Error("Cannot start terminated process") unless @childProcess?

    @handleEvents()
    @callback = args.pop() if _.isFunction(args[args.length - 1])
    @childProcess.send({args})

  # Public: Forcefully stop the running task.
  #
  # No events are emitted.
  terminate: ->
    return unless @childProcess?

    @childProcess.removeAllListeners()
    @childProcess.kill()
    @childProcess = null

    @off()
