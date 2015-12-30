_ = require 'underscore-plus'
child_process = require 'child_process'
{Emitter} = require 'emissary'

# Public: Run a node script in a separate process.
#
# Used by the fuzzy-finder.
#
# ## Examples
#
# ```coffee
# {Task} = require 'atom'
# ```
#
# ## Events
#
# ### task:log
#
# Emitted when console.log is called within the task.
#
# ### task:warn
#
# Emitted when console.warn is called within the task.
#
# ### task:error
#
# Emitted when console.error is called within the task.
#
# ### task:completed
#
# Emitted when the task has succeeded or failed.
#
module.exports =
class Task
  Emitter.includeInto(this)

  # Public: A helper method to easily launch and run a task once.
  #
  # * `taskPath` The {String} path to the CoffeeScript/JavaScript file which
  #   exports a single {Function} to execute.
  # * `args` The arguments to pass to the exported function.
  #
  # Returns the created {Task}.
  @once: (taskPath, args...) ->
    task = new Task(taskPath)
    task.once 'task:completed', -> task.terminate()
    task.start(args...)
    task

  # Called upon task completion.
  #
  # It receives the same arguments that were passed to the task.
  #
  # If subclassed, this is intended to be overridden. However if {::start}
  # receives a completion callback, this is overridden.
  callback: null

  # Public: Creates a task.
  #
  # * `taskPath` The {String} path to the CoffeeScript/JavaScript file that
  #   exports a single {Function} to execute.
  constructor: (taskPath) ->
    coffeeCacheRequire = "require('#{require.resolve('./coffee-cache')}').register();"
    coffeeScriptRequire = "require('#{require.resolve('coffee-script')}').register();"
    taskBootstrapRequire = "require('#{require.resolve('./task-bootstrap')}');"
    bootstrap = """
      #{coffeeScriptRequire}
      #{coffeeCacheRequire}
      #{taskBootstrapRequire}
    """
    bootstrap = bootstrap.replace(/\\/g, "\\\\")

    taskPath = require.resolve(taskPath)
    taskPath = taskPath.replace(/\\/g, "\\\\")

    env = _.extend({}, process.env, {taskPath, userAgent: navigator.userAgent})
    args = [bootstrap, '--harmony_collections']
    @childProcess = child_process.fork '--eval', args, {env, cwd: __dirname}

    @on "task:log", -> console.log(arguments...)
    @on "task:warn", -> console.warn(arguments...)
    @on "task:error", -> console.error(arguments...)
    @on "task:completed", (args...) => @callback?(args...)

    @handleEvents()

  # Routes messages from the child to the appropriate event.
  handleEvents: ->
    @childProcess.removeAllListeners()
    @childProcess.on 'message', ({event, args}) =>
      @emit(event, args...)

  # Public: Starts the task.
  #
  # Throws an error if this task has already been terminated or if sending a
  # message to the child process fails.
  #
  # * `args` The arguments to pass to the function exported by this task's script.
  # * `callback` (optional) A {Function} to call when the task completes.
  start: (args..., callback) ->
    throw new Error('Cannot start terminated process') unless @childProcess?

    @handleEvents()
    if _.isFunction(callback)
      @callback = callback
    else
      args.push(callback)
    @send({event: 'start', args})
    undefined

  # Public: Send message to the task.
  #
  # Throws an error if this task has already been terminated or if sending a
  # message to the child process fails.
  #
  # * `message` The message to send to the task.
  send: (message) ->
    if @childProcess?
      @childProcess.send(message)
    else
      throw new Error('Cannot send message to terminated process')
    undefined

  # Public: Forcefully stop the running task.
  #
  # No more events are emitted once this method is called.
  terminate: ->
    return unless @childProcess?

    @childProcess.removeAllListeners()
    @childProcess.kill()
    @childProcess = null

    @off()
    undefined
