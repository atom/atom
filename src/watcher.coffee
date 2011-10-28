module.exports =
class Watcher
  @watchedPaths: {}

  @setup: ->
    __AAWatcher__ = OSX.JSCocoa.createClass_parentClass "__AAWatcher__", "NSObject"
    OSX.JSCocoa.addInstanceMethod_class_jsFunction_encoding "watcher:receivedNotification:forPath:", __AAWatcher__, @watcher_receivedNotification_forPath, "v:@@@@"

    @delegate = __AAWatcher__.alloc.init
    @queue = OSX.UKKQueue.alloc.init
    @queue.setDelegate @delegate

  @watch: (path, callback) ->
    @setup() unless @queue?

    path = OSX.NSString.stringWithString(path).stringByStandardizingPath
    @queue.addPath path if not @watchedPaths[path]

    (@watchedPaths[path] ?= []).push callback

    callback # Handy for anonymous functions.

  @unwatch: (path, callback=null) ->
    return unless @watchedPaths[path]

    @watchedPaths[path] = (item for item in @watchedPaths[path] when item != callback)
    if not callback? or @watchedPaths[path].length == 0
      @watchedPaths[path] = null
      @queue.removePathFromQueue path

  # Delegate method for AAWatcher
  @watcher_receivedNotification_forPath = (queue, notification, path) =>
    callbacks = @watchedPaths[path]

    switch notification.toString()
      when "UKKQueueFileRenamedNotification"
        throw "Doesn't handle this yet"
      when "UKKQueueFileDeletedNotification"
        @watchedPaths[path] = null
        @queue.removePathFromQueue path
      when "UKKQueueFileWrittenToNotification"
        callback notification, path, callback for callback in callbacks
      when "UKKQueueFileAttributesChangedNotification"
        # Just ignore this
      else
        console.error "I HAVE NO IDEA WHEN #{notification} IS TRIGGERED"
