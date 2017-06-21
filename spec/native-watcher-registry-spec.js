/** @babel */

import path from 'path'
import {Emitter} from 'event-kit'

import NativeWatcherRegistry from '../src/native-watcher-registry'

class MockWatcher {
  constructor () {
    this.native = null
  }

  attachToNative (native) {
    this.native = native
    this.native.attached.push(this)
  }
}

class MockNative {
  constructor (name) {
    this.name = name
    this.attached = []
    this.disposed = false
    this.stopped = false

    this.emitter = new Emitter()
  }

  reattachTo (newNative) {
    for (const watcher of this.attached) {
      watcher.attachToNative(newNative)
    }

    this.attached = []
  }

  onDidStop (callback) {
    return this.emitter.on('did-stop', callback)
  }

  dispose () {
    this.disposed = true
  }

  stop () {
    this.stopped = true
    this.emitter.emit('did-stop')
  }
}

describe('NativeWatcherRegistry', function () {
  let registry, watcher

  beforeEach(function () {
    registry = new NativeWatcherRegistry()
    watcher = new MockWatcher()
  })

  it('attaches a Watcher to a newly created NativeWatcher for a new directory', function () {
    const NATIVE = new MockNative('created')
    registry.attach('/some/path', watcher, () => NATIVE)

    expect(watcher.native).toBe(NATIVE)
  })

  it('reuses an existing NativeWatcher on the same directory', function () {
    const EXISTING = new MockNative('existing')
    registry.attach('/existing/path', new MockWatcher(), () => EXISTING)

    registry.attach('/existing/path', watcher, () => new MockNative('no'))

    expect(watcher.native).toBe(EXISTING)
  })

  it('attaches to an existing NativeWatcher on a parent directory', function () {
    const EXISTING = new MockNative('existing')
    registry.attach('/existing/path', new MockWatcher(), () => EXISTING)

    registry.attach('/existing/path/sub/directory/', watcher, () => new MockNative('no'))

    expect(watcher.native).toBe(EXISTING)
  })

  it('adopts Watchers from NativeWatchers on child directories', function () {
    const EXISTING0 = new MockNative('existing0')
    const watcher0 = new MockWatcher()
    registry.attach('/existing/path/child/directory/zero', watcher0, () => EXISTING0)

    const EXISTING1 = new MockNative('existing1')
    const watcher1 = new MockWatcher()
    registry.attach('/existing/path/child/directory/one', watcher1, () => EXISTING1)

    const EXISTING2 = new MockNative('existing2')
    const watcher2 = new MockWatcher()
    registry.attach('/another/path', watcher2, () => EXISTING2)

    expect(watcher0.native).toBe(EXISTING0)
    expect(watcher1.native).toBe(EXISTING1)
    expect(watcher2.native).toBe(EXISTING2)

    // Consolidate all three watchers beneath the same native watcher on the parent directory
    const CREATED = new MockNative('created')
    registry.attach('/existing/path/', watcher, () => CREATED)

    expect(watcher.native).toBe(CREATED)

    expect(watcher0.native).toBe(CREATED)
    expect(EXISTING0.stopped).toBe(true)
    expect(EXISTING0.disposed).toBe(true)

    expect(watcher1.native).toBe(CREATED)
    expect(EXISTING1.stopped).toBe(true)
    expect(EXISTING1.disposed).toBe(true)

    expect(watcher2.native).toBe(EXISTING2)
    expect(EXISTING2.stopped).toBe(false)
    expect(EXISTING2.disposed).toBe(false)
  })

  describe('removing NativeWatchers', function () {
    it('happens when they stop', function () {
      const STOPPED = new MockNative('stopped')
      const stoppedWatcher = new MockWatcher()
      const stoppedPath = ['watcher', 'that', 'will', 'be', 'stopped']
      registry.attach(path.join(...stoppedPath), stoppedWatcher, () => STOPPED)

      const RUNNING = new MockNative('running')
      const runningWatcher = new MockWatcher()
      const runningPath = ['watcher', 'that', 'will', 'continue', 'to', 'exist']
      registry.attach(path.join(...runningPath), runningWatcher, () => RUNNING)

      STOPPED.stop()

      const runningNode = registry.tree.lookup(runningPath).when({
        parent: node => node,
        missing: () => false,
        children: () => false
      })
      expect(runningNode).toBeTruthy()
      expect(runningNode.getNativeWatcher()).toBe(RUNNING)

      const stoppedNode = registry.tree.lookup(stoppedPath).when({
        parent: () => false,
        missing: () => true,
        children: () => false
      })
      expect(stoppedNode).toBe(true)
    })

    it("keeps a parent watcher that's still running")

    it('reassigns new child watchers when a parent watcher is stopped')
  })
})
