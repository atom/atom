'use babel'

import {Emitter, CompositeDisposable} from 'event-kit'
import ipc from 'ipc'

export default class Update {
  constructor () {
    this.subscriptions = new CompositeDisposable()
    this.emitter = new Emitter()
  }

  initialize () {
    atom.applicationDelegate.onDidBeginDownloadingUpdate(() => {
      this.emitter.emit('did-begin-downloading-update')
    })
    atom.applicationDelegate.onDidBeginCheckingForUpdate(() => {
      this.emitter.emit('did-begin-checking-for-update')
    })
    atom.applicationDelegate.onUpdateAvailable(() => {
      this.emitter.emit('did-complete-downloading-update')
    })
  }

  dispose () {
    this.subscriptions.dispose()
  }

  onDidBeginCheckingForUpdate (callback) {
    this.subscriptions.add(
      this.emitter.on('did-begin-checking-for-update', callback)
    )
  }

  onDidBeginDownload (callback) {
    this.subscriptions.add(
      this.emitter.on('did-begin-downloading-update', callback)
    )
  }

  onDidCompleteDownload (callback) {
    this.subscriptions.add(
      this.emitter.on('did-complete-downloading-update', callback)
    )
  }

  onUpdateAvailable (callback) {
    this.subscriptions.add(
      this.emitter.on('update-available', callback)
    )
  }

  onUpdateNotAvailable (callback) {
    this.subscriptions.add(
      this.emitter.on('update-not-available', callback)
    )
  }

  check () {
    ipc.send('check-for-update')
  }
}
