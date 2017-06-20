/** @babel */

import fs from 'fs'
import path from 'path'

import {Emitter, CompositeDisposable} from 'event-kit'
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

  // Private: Register a callback to be invoked with normalized filesystem events as they arrive.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
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
    console.error(err)
  }
}

class Watcher {
  constructor (watchedPath) {
    this.watchedPath = watchedPath
    this.normalizedPath = null

    this.emitter = new Emitter()
    this.subs = new CompositeDisposable()
  }

  onDidStart (callback) {
    return this.emitter.on('did-start', callback)
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  attachToNative (native) {
    this.subs.dispose()

    if (native.isRunning()) {
      this.emitter.emit('did-start')
    } else {
      this.subs.add(native.onDidStart(payload => {
        this.emitter.emit('did-start', payload)
      }))
    }

    this.subs.add(native.onDidChange(events => {
      // TODO does event.oldPath resolve symlinks?
      const filtered = events.filter(event => event.oldPath.startsWith(this.normalizedPath))

      if (filtered.length > 0) {
        this.emitter.emit('did-change', filtered)
      }
    }))

    this.subs.add(native.onShouldDetach(
      this.attachToNative.bind(this)
    ))
  }

  dispose () {
    this.emitter.dispose()
    this.subs.dispose()
  }
}

export default class FileSystemManager {
  constructor () {
    this.nativeWatchers = new NativeWatcherRegistry()
  }

  getWatcher (rootPath) {
    const watcher = new Watcher(rootPath)

    const init = async () => {
      const normalizedPath = await new Promise((resolve, reject) => {
        fs.realpath(rootPath, (err, real) => (err ? reject(err) : resolve(real)))
      })
      watcher.normalizedPath = normalizedPath

      this.nativeWatchers.attach(normalizedPath, watcher, () => new NativeWatcher(normalizedPath))
    }
    init()

    return watcher
  }
}
