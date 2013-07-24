_ = require 'underscore'

module.exports =
class RateLimitedChannel
  _.extend @prototype, require('event-emitter')

  constructor: (@channel) ->
    @queue = []

    setInterval(@sendBatch, 200)
    @channel.bind_all (eventName, args...) =>
      if eventName is 'client-batch'
        @receiveBatch(args...)
      else
        @trigger eventName, args...

  receiveBatch: (batch) =>
    @trigger event... for event in batch

  sendBatch: =>
    return if @queue.length is 0

    batch = []
    batchSize = 2
    while event = @queue.shift()
      eventJson = JSON.stringify(event)
      if batchSize + eventJson.length > 10000
        console.log 'over 10k in batch, bailing'
        @queue.unshift(event)
        break
      else
        batch.push(eventJson)
        batchSize += eventJson.length + 1

    console.log 'sending batch'
    @channel.trigger 'client-batch', "[#{batch.join(',')}]"

  send: (args...) ->
    @queue.push(args)
