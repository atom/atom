/** @babel */

import {it, beforeEach, afterEach, promisifySome} from './async-spec-helpers'
import tempCb from 'temp'
import fsCb from 'fs-plus'
import path from 'path'

import {CompositeDisposable} from 'event-kit'
import FileSystemManager, {stopAllWatchers} from '../src/filesystem-manager'

tempCb.track()

const fs = promisifySome(fsCb, ['writeFile', 'mkdir', 'symlink', 'appendFile', 'realpath'])
const temp = promisifySome(tempCb, ['mkdir', 'cleanup'])

describe('FileSystemManager', function () {
  let subs, manager

  beforeEach(function () {
    subs = new CompositeDisposable()
    manager = new FileSystemManager()
  })

  afterEach(async function () {
    subs.dispose()

    await stopAllWatchers(manager)
  })

  function waitForChanges (watcher, ...fileNames) {
    const waiting = new Set(fileNames)
    const relevantEvents = []

    return new Promise(resolve => {
      const sub = watcher.onDidChange(events => {
        for (const event of events) {
          if (waiting.delete(event.oldPath)) {
            relevantEvents.push(event)
          }
        }

        if (waiting.size === 0) {
          resolve(relevantEvents)
          sub.dispose()
        }
      })
    })
  }

  describe('getWatcher()', function () {
    it('resolves getStartPromise() when the watcher begins listening', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-')

      const watcher = manager.getWatcher(rootDir)
      watcher.onDidChange(() => {})

      await watcher.getStartPromise()
    })

    it('does not start actually watching until an onDidChange subscriber is registered', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-')
      const watcher = manager.getWatcher(rootDir)

      let started = false
      const startPromise = watcher.getStartPromise().then(() => {
        started = true
      })

      expect(watcher.native).toBe(null)
      expect(watcher.normalizedPath).toBe(null)
      expect(started).toBe(false)

      await watcher.getNormalizedPathPromise()

      expect(watcher.native).toBe(null)
      expect(watcher.normalizedPath).not.toBe(null)
      expect(started).toBe(false)

      watcher.onDidChange(() => {})
      await startPromise

      expect(watcher.native).not.toBe(null)
      expect(started).toBe(true)
    })

    it('automatically stops and removes the watcher when all onDidChange subscribers dispose', async function () {
      const dir = await temp.mkdir('atom-fsmanager-')
      const watcher = manager.getWatcher(dir)

      const sub0 = watcher.onDidChange(() => {})
      const sub1 = watcher.onDidChange(() => {})

      await watcher.getStartPromise()
      expect(watcher.native).not.toBe(null)
      expect(watcher.native.isRunning()).toBe(true)

      sub0.dispose()
      expect(watcher.native.isRunning()).toBe(true)

      sub1.dispose()
      expect(watcher.native.isRunning()).toBe(false)
    })

    it('reuses an existing native watcher and resolves getStartPromise immediately if attached to a running watcher', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-')

      const watcher0 = manager.getWatcher(rootDir)
      watcher0.onDidChange(() => {})
      await watcher0.getStartPromise()

      const watcher1 = manager.getWatcher(rootDir)
      watcher1.onDidChange(() => {})
      await watcher1.getStartPromise()

      expect(watcher0.native).toBe(watcher1.native)
    })

    it('reuses an existing native watcher on a parent directory and filters events', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-').then(fs.realpath)

      const rootFile = path.join(rootDir, 'rootfile.txt')
      const subDir = path.join(rootDir, 'subdir')
      const subFile = path.join(subDir, 'subfile.txt')
      await Promise.all([
        fs.mkdir(subDir).then(
          fs.writeFile(subFile, 'subfile\n', {encoding: 'utf8'})
        ),
        fs.writeFile(rootFile, 'rootfile\n', {encoding: 'utf8'})
      ])

      const rootWatcher = manager.getWatcher(rootDir)
      const childWatcher = manager.getWatcher(subDir)

      expect(rootWatcher.native).toBe(childWatcher.native)

      const firstRootChange = waitForChanges(rootWatcher, subFile)
      const firstChildChange = waitForChanges(childWatcher, subFile)

      await Promise.all([
        rootWatcher.getStartPromise(),
        childWatcher.getStartPromise()
      ])

      await fs.appendFile(subFile, 'changes\n', {encoding: 'utf8'})

      const firstPayloads = await Promise.all([firstRootChange, firstChildChange])

      for (const events of firstPayloads) {
        expect(events.length).toBe(1)
        expect(events[0].oldPath).toBe(subFile)
      }

      const nextRootEvent = waitForChanges(rootWatcher, rootFile)
      await fs.appendFile(rootFile, 'changes\n', {encoding: 'utf8'})

      const nextPayload = await nextRootEvent

      expect(nextPayload.length).toBe(1)
      expect(nextPayload[0].oldPath).toBe(rootFile)
    })

    it('adopts existing child watchers and filters events appropriately to them', async function () {
      const parentDir = await temp.mkdir('atom-fsmanager-').then(fs.realpath)

      // Create the directory tree
      const rootFile = path.join(parentDir, 'rootfile.txt')
      const subDir0 = path.join(parentDir, 'subdir0')
      const subFile0 = path.join(subDir0, 'subfile1.txt')
      const subDir1 = path.join(parentDir, 'subdir1')
      const subFile1 = path.join(subDir1, 'subfile1.txt')

      await Promise.all([
        fs.writeFile(rootFile, 'rootfile\n', {encoding: 'utf8'}),
        fs.mkdir(subDir0).then(
          fs.writeFile(subFile0, 'subfile 0\n', {encoding: 'utf8'})
        ),
        fs.mkdir(subDir1).then(
          fs.writeFile(subFile1, 'subfile 1\n', {encoding: 'utf8'})
        )
      ])

      // Begin the child watchers
      const subWatcher0 = manager.getWatcher(subDir0)
      const subWatcherChanges0 = waitForChanges(subWatcher0, subFile0)

      const subWatcher1 = manager.getWatcher(subDir1)
      const subWatcherChanges1 = waitForChanges(subWatcher1, subFile1)

      await Promise.all(
        [subWatcher0, subWatcher1].map(watcher => {
          return watcher.getStartPromise()
        })
      )
      expect(subWatcher0.native).not.toBe(subWatcher1.native)

      // Create the parent watcher
      const parentWatcher = manager.getWatcher(parentDir)
      const parentWatcherChanges = waitForChanges(parentWatcher, rootFile, subFile0, subFile1)

      await parentWatcher.getStartPromise()

      expect(subWatcher0.native).toBe(parentWatcher.native)
      expect(subWatcher1.native).toBe(parentWatcher.native)

      // Ensure events are filtered correctly
      await Promise.all([
        fs.appendFile(rootFile, 'change\n', {encoding: 'utf8'}),
        fs.appendFile(subFile0, 'change\n', {encoding: 'utf8'}),
        fs.appendFile(subFile1, 'change\n', {encoding: 'utf8'})
      ])

      await Promise.all([
        subWatcherChanges0,
        subWatcherChanges1,
        parentWatcherChanges
      ])
    })

    describe('event normalization', function () {
      xit('normalizes "changed" events')
      xit('normalizes "added" events')
      xit('normalizes "deleted" events')
      xit('normalizes "renamed" events')
    })

    describe('symlinks', function () {
      xit('reports events with symlink paths')
      xit('uses the same native watcher even for symlink paths')
    })
  })
})
