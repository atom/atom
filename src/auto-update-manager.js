'use babel'

import {Emitter, CompositeDisposable} from 'event-kit'
import {ipcRenderer} from 'electron'

export default class AutoUpdateManager {
  constructor () {
    this.subscriptions = new CompositeDisposable()
    this.emitter = new Emitter()
  }

  initialize (updateEventEmitter) {
    this.subscriptions.add(
      updateEventEmitter.onDidBeginCheckingForUpdate(() => {
        this.emitter.emit('did-begin-checking-for-update')
      }),
      updateEventEmitter.onDidBeginDownloadingUpdate(() => {
        this.emitter.emit('did-begin-downloading-update')
      }),
      updateEventEmitter.onDidCompleteDownloadingUpdate((details) => {
        this.emitter.emit('did-complete-downloading-update', details)
      }),
      updateEventEmitter.onUpdateNotAvailable(() => {
        this.emitter.emit('update-not-available')
      })
    )
  }

  dispose () {
    this.subscriptions.dispose()
    this.emitter.dispose()
  }

  onDidBeginCheckingForUpdate (callback) {
    return this.emitter.on('did-begin-checking-for-update', callback)
  }

  onDidBeginDownloadingUpdate (callback) {
    return this.emitter.on('did-begin-downloading-update', callback)
  }

  onDidCompleteDownloadingUpdate (callback) {
    return this.emitter.on('did-complete-downloading-update', callback)
  }

  onUpdateNotAvailable (callback) {
    return this.emitter.on('update-not-available', callback)
  }

  checkForUpdate () {
    ipcRenderer.send('check-for-update')
  }
}
