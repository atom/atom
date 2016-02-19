'use babel'

import Update from '../src/update'
import remote from 'remote'
import ipc from 'ipc'

fdescribe('Update', () => {
  let update

  afterEach(() => {
    update.dispose()
  })

  describe('::initialize', () => {
    it('subscribes to appropriate applicationDelegate events', () => {
      update = new Update()

      const downloadingSpy = jasmine.createSpy('downloadingSpy')
      const checkingSpy = jasmine.createSpy('checkingSpy')
      const noUpdateSpy = jasmine.createSpy('noUpdateSpy')
      const completedDownloadSpy = jasmine.createSpy('completedDownloadSpy')

      update.emitter.on('did-begin-checking-for-update', checkingSpy)
      update.emitter.on('did-begin-downloading-update', downloadingSpy)
      update.emitter.on('did-complete-downloading-update', completedDownloadSpy)
      update.emitter.on('update-not-available', noUpdateSpy)

      update.initialize()

      const webContents = remote.getCurrentWebContents()
      webContents.send('message', 'checking-for-update')
      webContents.send('message', 'did-begin-downloading-update')
      webContents.send('message', 'update-available', {releaseVersion: '1.2.3'})
      webContents.send('message', 'update-not-available')

      waitsFor(() => {
        return noUpdateSpy.callCount > 0
      })

      runs(() => {
        expect(downloadingSpy.callCount).toBe(1)
        expect(checkingSpy.callCount).toBe(1)
        expect(noUpdateSpy.callCount).toBe(1)
        expect(completedDownloadSpy.callCount).toBe(1)
      })
    })
  })

  beforeEach(() => {
    update = new Update()
    update.initialize()
  })

  describe('::onDidBeginCheckingForUpdate', () => {
    it('subscribes to "did-begin-checking-for-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidBeginCheckingForUpdate(spy)
      update.emitter.emit('did-begin-checking-for-update')
      expect(spy.callCount).toBe(1)
    })
  })

  describe('::onDidBeginDownload', () => {
    it('subscribes to "did-begin-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidBeginDownload(spy)
      update.emitter.emit('did-begin-downloading-update')
      expect(spy.callCount).toBe(1)
    })
  })

  describe('::onDidCompleteDownload', () => {
    it('subscribes to "did-complete-downloading-update" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onDidCompleteDownload(spy)
      update.emitter.emit('did-complete-downloading-update')
      expect(spy.callCount).toBe(1)
    })
  })

  describe('::onUpdateNotAvailable', () => {
    it('subscribes to "update-not-available" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onUpdateNotAvailable(spy)
      update.emitter.emit('update-not-available')
      expect(spy.callCount).toBe(1)
    })
  })

  describe('::onUpdateAvailable', () => {
    it('subscribes to "update-available" event', () => {
      const spy = jasmine.createSpy('spy')
      update.onUpdateAvailable(spy)
      update.emitter.emit('update-available')
      expect(spy.callCount).toBe(1)
    })
  })

  // TODO: spec is timing out. spy is not called
  // describe('::check', () => {
  //   it('sends "check-for-update" event', () => {
  //     const spy = jasmine.createSpy('spy')
  //     ipc.on('check-for-update', () => {
  //       spy()
  //     })
  //     update.check()
  //     waitsFor(() => {
  //       return spy.callCount > 0
  //     })
  //   })
  // })

  describe('::dispose', () => {
    it('disposes of subscriptions', () => {
      expect(update.subscriptions.disposables).not.toBeNull()
      update.dispose()
      expect(update.subscriptions.disposables).toBeNull()
    })
  })

})
