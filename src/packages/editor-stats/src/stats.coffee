module.exports =
class Stats
  startDate: new Date
  hours: 6
  eventLog: []

  constructor: ->
    date = new Date(@startDate)
    future = new Date(date.getTime() + (36e5 * @hours))
    @eventLog[@time(date)] = 0

    while date < future
      @eventLog[@time(date)] = 0

  clear: ->
    @eventLog = []

  track: ->
    date = new Date
    times = @time date
    @eventLog[times] ?= 0
    @eventLog[times] += 1
    @eventLog.shift() if @eventLog.length > (@hours * 60)

  time: (date) ->
    date.setTime(date.getTime() + 6e4)
    hour = date.getHours()
    minute = date.getMinutes()
    "#{hour}:#{minute}"
