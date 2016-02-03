'use babel'

import Update from '../src/update'
import remote from 'remote'

fdescribe('Update', () => {
  describe('::initialize', () => {
    it('subscribes to appropriate applicationDelegate events', () => {
      const update = new Update()
      update.initialize()

      const downloadingSpy = jasmine.createSpy('downloadingSpy')
      const checkingSpy = jasmine.createSpy('checkingSpy')
      const noUpdateSpy = jasmine.createSpy('noUpdateSpy')

      update.onDidBeginCheckingForUpdate(checkingSpy)
      update.onDidBeginDownload(downloadingSpy)
      update.onUpdateNotAvailable(noUpdateSpy)

      const webContents = remote.getCurrentWebContents()
      // AutoUpdateManager sends these from main process land
      webContents.send('update-available', {releaseVersion: '1.2.3'})
      webContents.send('did-begin-downloading-update')
      webContents.send('checking-for-update')
      webContents.send('update-not-available')

      waitsFor(() => {
        noUpdateSpy.callCount > 0
      })
      runs(() => {
        expect(downloadingSpy.callCount).toBe(1)
        expect(checkingSpy.callCount).toBe(1)
        expect(noUpdateSpy.callCount).toBe(1)
      })
    })
  })
})
