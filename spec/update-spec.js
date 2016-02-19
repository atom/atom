'use babel'

import Update from '../src/update'
import {remote} from 'electron'
const electronAutoUpdater = remote.require('electron').autoUpdater

describe('Update', () => {
  let update

  beforeEach(() => {
    update = new Update()
    update.initialize()
  })

  afterEach(() => {
    update.dispose()
  })

  describe('::onDidBeginCheckingForUpdate', () => {
    it('subscribes to "did-begin-checking-for-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidBeginCheckingForUpdate(spy)
      electronAutoUpdater.emit('checking-for-update')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onDidBeginDownload', () => {
    it('subscribes to "did-begin-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidBeginDownload(spy)
      electronAutoUpdater.emit('update-available')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onDidCompleteDownload', () => {
    it('subscribes to "did-complete-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidCompleteDownload(spy)
      electronAutoUpdater.emit('update-downloaded', null, null, {releaseVersion: '1.2.3'})
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onUpdateNotAvailable', () => {
    it('subscribes to "update-not-available" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onUpdateNotAvailable(spy)
      electronAutoUpdater.emit('update-not-available')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

})
