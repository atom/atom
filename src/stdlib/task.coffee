_ = require 'underscore'
child_process = require 'child_process'
EventEmitter = require 'event-emitter'

module.exports =
class Task
  @once: (taskPath, args...) ->
    task = new Task(taskPath)
    task.one 'task:completed', -> task.terminate()
    task.start(args...)
    task

  callback: null

  constructor: (taskPath) ->
    bootstrap = """
      require('coffee-script');
      require('coffee-cache').setCacheDir('/tmp/atom-coffee-cache');
      require('task-bootstrap');
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

  handleEvents: ->
    @childProcess.removeAllListeners()
    @childProcess.on 'message', ({event, args}) =>
      @trigger(event, args...)

  start: (args...) ->
    throw new Error("Cannot start terminated process") unless @childProcess?

    @handleEvents()
    @callback = args.pop() if _.isFunction(args[args.length - 1])
    @childProcess.send({args})

  terminate: ->
    return unless @childProcess?

    @childProcess.removeAllListeners()
    @childProcess.kill()
    @childProcess = null

    @off()

_.extend Task.prototype, EventEmitter
