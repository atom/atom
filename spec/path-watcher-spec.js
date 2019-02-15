/** @babel */

import {it, beforeEach, afterEach, promisifySome} from './async-spec-helpers'
import tempCb from 'temp'
import fsCb from 'fs-plus'
import path from 'path'

import {CompositeDisposable} from 'event-kit'
import {watchPath, stopAllWatchers} from '../src/path-watcher'

tempCb.track()

const fs = promisifySome(fsCb, ['writeFile', 'mkdir', 'symlink', 'appendFile', 'realpath'])
const temp = promisifySome(tempCb, ['mkdir'])

class ScopedLogger {
  constructor () {
    this.messages = []
  }

  enable (iteration) {
    this.iteration = iteration
  }

  log (message) {
    if (!this.iteration) {
      return
    }
    this.messages.push(message)
  }

  async dump () {
    if (!this.iteration) {
      return
    }
    const fileName = `path-watcher-spec.${this.iteration}.log`
    const content = this.messages.map(line => line + '\n').join('')
    await fs.writeFile(fileName, content, {encoding: 'utf8'})
    process.stdout.write(`\n##vso[artifact.upload containerfolder=path-watcher-spec-logs;artifactname=${fileName};]${fileName}\n`)
  }
}

describe('watchPath', function () {
  let subs, logger

  beforeEach(function () {
    logger = new ScopedLogger()
    subs = new CompositeDisposable()
  })

  afterEach(async function () {
    subs.dispose()
    await stopAllWatchers()
    await logger.dump()
  })

  function waitForChanges (watcher, ...fileNames) {
    const waiting = new Set(fileNames)
    let fired = false
    const relevantEvents = []
    logger.log(`waitForChanges: waiting for filenames - [${fileNames.join(', ')}]`)

    return new Promise(resolve => {
      const sub = watcher.onDidChange(events => {
        logger.log(`waitForChanges: received ${events.length} events`)
        for (const event of events) {
          if (waiting.delete(event.path)) {
            logger.log(`waitForChanges: matched [${event.path}]`)
            relevantEvents.push(event)
          } else {
            logger.log(`waitForChanges: ignoring unexpected event [${event.path}]`)
          }
        }

        if (!fired && waiting.size === 0) {
          logger.log(`waitForChanges: all expected events received, resolving`)
          fired = true
          resolve(relevantEvents)
          sub.dispose()
        } else if (!fired) {
          logger.log(`waitForChanges: ${waiting.size} events still to come`)
        } else {
          logger.log(`waitForChanges: already fired`)
        }
      })
    })
  }

  describe('watchPath()', function () {
    it('resolves the returned promise when the watcher begins listening', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-test-')

      const watcher = await watchPath(rootDir, {}, () => {})
      expect(watcher.constructor.name).toBe('PathWatcher')
    })

    it('reuses an existing native watcher and resolves getStartPromise immediately if attached to a running watcher', async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-test-')

      const watcher0 = await watchPath(rootDir, {}, () => {})
      const watcher1 = await watchPath(rootDir, {}, () => {})

      expect(watcher0.native).toBe(watcher1.native)
    })

    it("reuses existing native watchers even while they're still starting", async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-test-')

      const [watcher0, watcher1] = await Promise.all([
        watchPath(rootDir, {}, () => {}),
        watchPath(rootDir, {}, () => {})
      ])
      expect(watcher0.native).toBe(watcher1.native)
    })

    it("doesn't attach new watchers to a native watcher that's stopping", async function () {
      const rootDir = await temp.mkdir('atom-fsmanager-test-')

      const watcher0 = await watchPath(rootDir, {}, () => {})
      const native0 = watcher0.native

      watcher0.dispose()
      const watcher1 = await watchPath(rootDir, {}, () => {})

      expect(watcher1.native).not.toBe(native0)
    })

    fdescribe('the flaking test', function() {
      for (let i = 0; i < 100; i++) {
        it(`reuses an existing native watcher on a parent directory and filters events: ${i}`, async function () {
          logger.enable(i)
          logger.log('start')

          logger.log('creating fixture paths: start')
          const rootDir = await temp.mkdir('atom-fsmanager-test-').then(fs.realpath)
          const rootFile = path.join(rootDir, 'rootfile.txt')
          const subDir = path.join(rootDir, 'subdir')
          const subFile = path.join(subDir, 'subfile.txt')

          await fs.mkdir(subDir)
          logger.log(`rootDir=[${rootDir}] rootFile=[${rootFile} subDir=[${subDir}] subFile=[${subFile}]]`)
          logger.log('creating fixture paths: done')

          // Keep the watchers alive with an undisposed subscription
          logger.log('creating watchers: start')
          logger.log(`watching: [${rootDir}]`)
          const rootWatcher = await watchPath(rootDir, {}, () => {})
          logger.log(`watching: [${subDir}]`)
          const childWatcher = await watchPath(subDir, {}, () => {})
          logger.log('creating watchers: done')

          expect(rootWatcher.native).toBe(childWatcher.native)
          expect(rootWatcher.native.isRunning()).toBe(true)

          logger.log('creating promise for first changes: start')
          const firstChanges = Promise.all([
            waitForChanges(rootWatcher, subFile),
            waitForChanges(childWatcher, subFile)
          ])
          logger.log('creating promise for first changes: done')

          logger.log(`writing to ${subFile}: start`)
          await fs.writeFile(subFile, 'subfile\n', {encoding: 'utf8'})
          logger.log(`writing to ${subFile}: done`)
          logger.log(`await promise for first changes: start`)
          await firstChanges
          logger.log(`await promise for first changes: done`)

          logger.log('creating promise for root changes: start')
          const nextRootEvent = waitForChanges(rootWatcher, rootFile)
          logger.log('creating promise for root changes: done')
          logger.log(`writing to ${rootFile}: start`)
          await fs.writeFile(rootFile, 'rootfile\n', {encoding: 'utf8'})
          logger.log(`writing to ${rootFile}: done`)
          logger.log('await promise for root changes: start')
          await nextRootEvent
          logger.log('await promise for root changes: done')

          logger.log('done')
        })
      }
    })

    it('adopts existing child watchers and filters events appropriately to them', async function () {
      const parentDir = await temp.mkdir('atom-fsmanager-test-').then(fs.realpath)

      // Create the directory tree
      const rootFile = path.join(parentDir, 'rootfile.txt')
      const subDir0 = path.join(parentDir, 'subdir0')
      const subFile0 = path.join(subDir0, 'subfile0.txt')
      const subDir1 = path.join(parentDir, 'subdir1')
      const subFile1 = path.join(subDir1, 'subfile1.txt')

      await fs.mkdir(subDir0)
      await fs.mkdir(subDir1)
      await Promise.all([
        fs.writeFile(rootFile, 'rootfile\n', {encoding: 'utf8'}),
        fs.writeFile(subFile0, 'subfile 0\n', {encoding: 'utf8'}),
        fs.writeFile(subFile1, 'subfile 1\n', {encoding: 'utf8'})
      ])

      // Begin the child watchers and keep them alive
      const subWatcher0 = await watchPath(subDir0, {}, () => {})
      const subWatcherChanges0 = waitForChanges(subWatcher0, subFile0)

      const subWatcher1 = await watchPath(subDir1, {}, () => {})
      const subWatcherChanges1 = waitForChanges(subWatcher1, subFile1)

      expect(subWatcher0.native).not.toBe(subWatcher1.native)

      // Create the parent watcher
      const parentWatcher = await watchPath(parentDir, {}, () => {})
      const parentWatcherChanges = waitForChanges(parentWatcher, rootFile, subFile0, subFile1)

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
  })
})
