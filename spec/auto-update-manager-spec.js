'use babel'

import AutoUpdateManager from '../src/auto-update-manager'
import {remote} from 'electron'
const electronAutoUpdater = remote.require('electron').autoUpdater

fdescribe('AutoUpdateManager (renderer)', () => {
  let autoUpdateManager

  beforeEach(() => {
    autoUpdateManager = new AutoUpdateManager()
    autoUpdateManager.initialize(atom.applicationDelegate)
  })

  afterEach(() => {
    autoUpdateManager.dispose()
  })

  describe('::onDidBeginCheckingForUpdate', () => {
    it('subscribes to "did-begin-checking-for-update" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onDidBeginCheckingForUpdate(spy)
      electronAutoUpdater.emit('checking-for-update')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onDidBeginDownload', () => {
    it('subscribes to "did-begin-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onDidBeginDownload(spy)
      electronAutoUpdater.emit('update-available')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onDidCompleteDownload', () => {
    it('subscribes to "did-complete-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onDidCompleteDownload(spy)
      electronAutoUpdater.emit('update-downloaded', null, null, {releaseVersion: '1.2.3'})
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onUpdateNotAvailable', () => {
    it('subscribes to "update-not-available" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onUpdateNotAvailable(spy)
      electronAutoUpdater.emit('update-not-available')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::dispose', () => {
    it('subscribes to "update-not-available" event', () => {
      const spy = jasmine.createSpy('spy')
      const doneIndicator = jasmine.createSpy('spy')
      atom.applicationDelegate.onUpdateNotAvailable(doneIndicator)
      autoUpdateManager.dispose()
      autoUpdateManager.onDidBeginCheckingForUpdate(spy)
      autoUpdateManager.onDidBeginDownload(spy)
      autoUpdateManager.onDidCompleteDownload(spy)
      autoUpdateManager.onUpdateNotAvailable(spy)
      electronAutoUpdater.emit('checking-for-update')
      electronAutoUpdater.emit('update-available')
      electronAutoUpdater.emit('update-downloaded', null, null, {releaseVersion: '1.2.3'})
      electronAutoUpdater.emit('update-not-available')

      waitsFor(() => {
        return doneIndicator.callCount === 1
      })

      runs(() => {
        expect(spy.callCount).toBe(0)
      })
    })
  })
})
