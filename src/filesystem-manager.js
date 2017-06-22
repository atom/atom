/** @babel */

import fs from 'fs'
import path from 'path'

import {Emitter, Disposable, CompositeDisposable} from 'event-kit'
import nsfw from 'nsfw'

import NativeWatcherRegistry from './native-watcher-registry'

// Private: Associate native watcher action type flags with descriptive String equivalents.
const ACTION_MAP = new Map([
  [nsfw.actions.MODIFIED, 'changed'],
  [nsfw.actions.CREATED, 'added'],
  [nsfw.actions.DELETED, 'deleted'],
  [nsfw.actions.RENAMED, 'renamed']
])

// Private: Interface with and normalize events from a native OS filesystem watcher.
class NativeWatcher {

  // Private: Initialize a native watcher on a path.
  //
  // Events will not be produced until {start()} is called.
  constructor (normalizedPath) {
    this.normalizedPath = normalizedPath
    this.emitter = new Emitter()

    this.watcher = null
    this.running = false
  }

  // Private: Begin watching for filesystem events.
  //
  // Has no effect if the watcher has already been started.
  async start () {
    if (this.running) {
      return
    }

    this.watcher = await nsfw(
      this.normalizedPath,
      this.onEvents.bind(this),
      {
        debounceMS: 100,
        errorCallback: this.onError.bind(this)
      }
    )

    await this.watcher.start()

    this.running = true
    this.emitter.emit('did-start')
  }

  // Private: Return true if the underlying watcher has been started.
  isRunning () {
    return this.running
  }

  // Private: Register a callback to be invoked when the filesystem watcher has been initialized.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidStart (callback) {
    return this.emitter.on('did-start', callback)
  }

  // Private: Register a callback to be invoked with normalized filesystem events as they arrive. Starts the watcher
  // automatically if it is not already running. The watcher will be stopped automatically when all subscribers
  // dispose their subscriptions.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidChange (callback) {
    if (!this.isRunning()) {
      this.start()
    }

    const sub = this.emitter.on('did-change', callback)
    return new Disposable(() => {
      sub.dispose()
      if (this.emitter.listenerCountForEventName('did-change') === 0) {
        this.stop()
      }
    })
  }

  // Private: Register a callback to be invoked when a {Watcher} should attach to a different {NativeWatcher}.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onShouldDetach (callback) {
    return this.emitter.on('should-detach', callback)
  }

  // Private: Register a callback to be invoked when the filesystem watcher has been initialized.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidStop (callback) {
    return this.emitter.on('did-stop', callback)
  }

  // Private: Broadcast an `onShouldDetach` event to prompt any {Watcher} instances bound here to attach to a new
  // {NativeWatcher} instead.
  reattachTo (other) {
    this.emitter.emit('should-detach', other)
  }

  // Private: Stop the native watcher and release any operating system resources associated with it.
  //
  // Has no effect if the watcher is not running.
  async stop () {
    if (!this.running) {
      return
    }

    await this.watcher.stop()
    this.running = false
    this.emitter.emit('did-stop')
  }

  // Private: Detach any event subscribers.
  dispose () {
    this.emitter.dispose()
  }

  // Private: Callback function invoked by the native watcher when a debounced group of filesystem events arrive.
  // Normalize and re-broadcast them to any subscribers.
  //
  // * `events` An Array of filesystem events.
  onEvents (events) {
    this.emitter.emit('did-change', events.map(event => {
      const type = ACTION_MAP.get(event.action) || `unexpected (${event.action})`
      const oldFileName = event.file || event.oldFile
      const newFileName = event.newFile
      const oldPath = path.join(event.directory, oldFileName)
      const newPath = newFileName && path.join(event.directory, newFileName)

      return {oldPath, newPath, type}
    }))
  }

  // Private: Callback function invoked by the native watcher when an error occurs.
  //
  // * `err` The native filesystem error.
  onError (err) {
    if (!this.isRunning()) {
      return
    }

    console.error(err)
  }
}

class Watcher {
  constructor (watchedPath, nativeWatcherRegistry) {
    this.watchedPath = watchedPath
    this.nativeWatcherRegistry = nativeWatcherRegistry

    this.normalizedPath = null
    this.native = null
    this.changeCallbacks = new Map()

    this.normalizedPathPromise = new Promise((resolve, reject) => {
      fs.realpath(watchedPath, (err, real) => {
        if (err) {
          reject(err)
          return
        }

        this.normalizedPath = real
        resolve(real)
      })
    })

    this.startPromise = new Promise(resolve => {
      this.resolveStartPromise = resolve
    })

    this.emitter = new Emitter()
    this.subs = new CompositeDisposable()
  }

  getNormalizedPathPromise () {
    return this.normalizedPathPromise
  }

  getStartPromise () {
    return this.startPromise
  }

  onDidChange (callback) {
    if (this.native) {
      const sub = this.native.onDidChange(events => this.onNativeEvents(events, callback))
      this.changeCallbacks.set(callback, sub)

      this.native.start()
    } else {
      // Attach and retry
      this.nativeWatcherRegistry.attach(this).then(() => {
        this.onDidChange(callback)
      })
    }

    return new Disposable(() => {
      const sub = this.changeCallbacks.get(callback)
      this.changeCallbacks.delete(callback)
      sub.dispose()
    })
  }

  attachToNative (native) {
    this.subs.dispose()
    this.native = native

    if (native.isRunning()) {
      this.resolveStartPromise()
    } else {
      this.subs.add(native.onDidStart(() => {
        this.resolveStartPromise()
      }))
    }

    // Transfer any native event subscriptions to the new NativeWatcher.
    for (const [callback, formerSub] of this.changeCallbacks) {
      const newSub = native.onDidChange(events => this.onNativeEvents(events, callback))
      this.changeCallbacks.set(callback, newSub)
      formerSub.dispose()
    }

    if (this.changeCallbacks.size > 0) {
      native.start()
    }

    this.subs.add(native.onShouldDetach(replacement => {
      if (replacement !== native) {
        this.attachToNative(replacement)
      }
    }))
  }

  onNativeEvents (events, callback) {
    // TODO does event.oldPath resolve symlinks?
    const filtered = events.filter(event => event.oldPath.startsWith(this.normalizedPath))

    if (filtered.length > 0) {
      callback(filtered)
    }
  }

  dispose () {
    for (const sub of this.changeCallbacks.values()) {
      sub.dispose()
    }

    this.emitter.dispose()
    this.subs.dispose()
  }
}

export default class FileSystemManager {
  constructor () {
    this.liveWatchers = new Set()

    this.nativeWatchers = new NativeWatcherRegistry(
      normalizedPath => {
        const nativeWatcher = new NativeWatcher(normalizedPath)

        this.liveWatchers.add(nativeWatcher)
        const sub = nativeWatcher.onDidStop(() => {
          this.liveWatchers.delete(nativeWatcher)
          sub.dispose()
        })

        return nativeWatcher
      }
    )
  }

  getWatcher (rootPath) {
    return new Watcher(rootPath, this.nativeWatchers)
  }
}

// Private: Return a Promise that resolves when all {NativeWatcher} instances associated with a FileSystemManager
// have stopped listening. This is useful for `afterEach()` blocks in unit tests.
export function stopAllWatchers (manager) {
  return Promise.all(
    Array.from(manager.liveWatchers, watcher => watcher.stop())
  )
}
