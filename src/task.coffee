_ = require 'underscore-plus'
ChildProcess = require 'child_process'
{Emitter} = require 'event-kit'
Grim = require 'grim'

# Extended: Run a node script in a separate process.
#
# Used by the fuzzy-finder and [find in project](https://github.com/atom/atom/blob/master/src/scan-handler.coffee).
#
# For a real-world example, see the [scan-handler](https://github.com/atom/atom/blob/master/src/scan-handler.coffee)
# and the [instantiation of the task](https://github.com/atom/atom/blob/4a20f13162f65afc816b512ad7201e528c3443d7/src/project.coffee#L245).
#
# ## Examples
#
# In your package code:
#
# ```coffee
# {Task} = require 'atom'
#
# task = Task.once '/path/to/task-file.coffee', parameter1, parameter2, ->
#   console.log 'task has finished'
#
# task.on 'some-event-from-the-task', (data) =>
#   console.log data.someString # prints 'yep this is it'
# ```
#
# In `'/path/to/task-file.coffee'`:
#
# ```coffee
# module.exports = (parameter1, parameter2) ->
#   # Indicates that this task will be async.
#   # Call the `callback` to finish the task
#   callback = @async()
#
#   emit('some-event-from-the-task', {someString: 'yep this is it'})
#
#   callback()
# ```
module.exports =
class Task
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

  # Public: Creates a task. You should probably use {.once}
  #
  # * `taskPath` The {String} path to the CoffeeScript/JavaScript file that
  #   exports a single {Function} to execute.
  constructor: (taskPath) ->
    @emitter = new Emitter

    compileCacheRequire = "require('#{require.resolve('./compile-cache')}')"
    compileCachePath = require('./compile-cache').getCacheDirectory()
    taskBootstrapRequire = "require('#{require.resolve('./task-bootstrap')}');"
    bootstrap = """
      CompileCache = #{compileCacheRequire}
      CompileCache.setCacheDirectory('#{compileCachePath}');
      CompileCache.install("#{process.resourcesPath}", require)
      #{taskBootstrapRequire}
    """
    bootstrap = bootstrap.replace(/\\/g, "\\\\")

    taskPath = require.resolve(taskPath)
    taskPath = taskPath.replace(/\\/g, "\\\\")

    env = _.extend({}, process.env, {taskPath, userAgent: navigator.userAgent})
    @childProcess = ChildProcess.fork '--eval', [bootstrap], {env, silent: true}

    @on "task:log", -> console.log(arguments...)
    @on "task:warn", -> console.warn(arguments...)
    @on "task:error", -> console.error(arguments...)
    @on "task:deprecations", (deprecations) ->
      Grim.addSerializedDeprecation(deprecation) for deprecation in deprecations
      return
    @on "task:completed", (args...) => @callback?(args...)

    @handleEvents()

  # Routes messages from the child to the appropriate event.
  handleEvents: ->
    @childProcess.removeAllListeners()
    @childProcess.on 'message', ({event, args}) =>
      @emitter.emit(event, args) if @childProcess?

    # Catch the errors that happened before task-bootstrap.
    if @childProcess.stdout?
      @childProcess.stdout.removeAllListeners()
      @childProcess.stdout.on 'data', (data) -> console.log data.toString()

    if @childProcess.stderr?
      @childProcess.stderr.removeAllListeners()
      @childProcess.stderr.on 'data', (data) -> console.error data.toString()

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

  # Public: Call a function when an event is emitted by the child process
  #
  # * `eventName` The {String} name of the event to handle.
  # * `callback` The {Function} to call when the event is emitted.
  #
  # Returns a {Disposable} that can be used to stop listening for the event.
  on: (eventName, callback) -> @emitter.on eventName, (args) -> callback(args...)

  once: (eventName, callback) ->
    disposable = @on eventName, (args...) ->
      disposable.dispose()
      callback(args...)

  # Public: Forcefully stop the running task.
  #
  # No more events are emitted once this method is called.
  terminate: ->
    return false unless @childProcess?

    @childProcess.removeAllListeners()
    @childProcess.stdout?.removeAllListeners()
    @childProcess.stderr?.removeAllListeners()
    @childProcess.kill()
    @childProcess = null

    true

  cancel: ->
    didForcefullyTerminate = @terminate()
    if didForcefullyTerminate
      @emitter.emit('task:cancelled')
    didForcefullyTerminate
