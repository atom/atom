'use babel'

import AutoUpdateManager from '../src/auto-update-manager'
import {remote} from 'electron'
const electronAutoUpdater = remote.require('electron').autoUpdater

describe('AutoUpdateManager (renderer)', () => {
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

  describe('::onDidBeginDownloadingUpdate', () => {
    it('subscribes to "did-begin-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onDidBeginDownloadingUpdate(spy)
      electronAutoUpdater.emit('update-available')
      waitsFor(() => {
        return spy.callCount === 1
      })
    })
  })

  describe('::onDidCompleteDownloadingUpdate', () => {
    it('subscribes to "did-complete-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      autoUpdateManager.onDidCompleteDownloadingUpdate(spy)
      electronAutoUpdater.emit('update-downloaded', null, null, '1.2.3')
      waitsFor(() => {
        return spy.callCount === 1
      })
      runs(() => {
        expect(spy.mostRecentCall.args[0].releaseVersion).toBe('1.2.3')
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

  describe('::isEnabled', () => {
    let platform, releaseChannel
    it('returns true on OS X and Windows, when in stable', () => {
      spyOn(autoUpdateManager, 'getPlatform').andCallFake(() =>  platform)
      spyOn(autoUpdateManager, 'getReleaseChannel').andCallFake(() => releaseChannel)

      platform = 'win32'
      releaseChannel = 'stable'
      expect(autoUpdateManager.isEnabled()).toBe(true)

      platform = 'win32'
      releaseChannel = 'dev'
      expect(autoUpdateManager.isEnabled()).toBe(false)

      platform = 'darwin'
      releaseChannel = 'stable'
      expect(autoUpdateManager.isEnabled()).toBe(true)

      platform = 'darwin'
      releaseChannel = 'dev'
      expect(autoUpdateManager.isEnabled()).toBe(false)

      platform = 'linux'
      releaseChannel = 'stable'
      expect(autoUpdateManager.isEnabled()).toBe(false)

      platform = 'linux'
      releaseChannel = 'dev'
      expect(autoUpdateManager.isEnabled()).toBe(false)
    })
  })

  describe('::dispose', () => {
    it('subscribes to "update-not-available" event', () => {
      const spy = jasmine.createSpy('spy')
      const doneIndicator = jasmine.createSpy('spy')
      atom.applicationDelegate.onUpdateNotAvailable(doneIndicator)
      autoUpdateManager.onDidBeginCheckingForUpdate(spy)
      autoUpdateManager.onDidBeginDownloadingUpdate(spy)
      autoUpdateManager.onDidCompleteDownloadingUpdate(spy)
      autoUpdateManager.onUpdateNotAvailable(spy)
      autoUpdateManager.dispose()
      electronAutoUpdater.emit('checking-for-update')
      electronAutoUpdater.emit('update-available')
      electronAutoUpdater.emit('update-downloaded', null, null, '1.2.3')
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
