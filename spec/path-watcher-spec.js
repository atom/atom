/** @babel */

import temp from 'temp';
import fs from 'fs-plus';
import path from 'path';
import { promisify } from 'util';

import { CompositeDisposable } from 'event-kit';
import { watchPath, stopAllWatchers } from '../src/path-watcher';

temp.track();

const writeFile = promisify(fs.writeFile);
const mkdir = promisify(fs.mkdir);
const appendFile = promisify(fs.appendFile);
const realpath = promisify(fs.realpath);

const tempMkdir = promisify(temp.mkdir);

describe('watchPath', function() {
  let subs;

  beforeEach(function() {
    subs = new CompositeDisposable();
  });

  afterEach(async function() {
    subs.dispose();
    await stopAllWatchers();
  });

  function waitForChanges(watcher, ...fileNames) {
    const waiting = new Set(fileNames);
    let fired = false;
    const relevantEvents = [];

    return new Promise(resolve => {
      const sub = watcher.onDidChange(events => {
        for (const event of events) {
          if (waiting.delete(event.path)) {
            relevantEvents.push(event);
          }
        }

        if (!fired && waiting.size === 0) {
          fired = true;
          resolve(relevantEvents);
          sub.dispose();
        }
      });
    });
  }

  describe('watchPath()', function() {
    it('resolves the returned promise when the watcher begins listening', async function() {
      const rootDir = await tempMkdir('atom-fsmanager-test-');

      const watcher = await watchPath(rootDir, {}, () => {});
      expect(watcher.constructor.name).toBe('PathWatcher');
    });

    it('reuses an existing native watcher and resolves getStartPromise immediately if attached to a running watcher', async function() {
      const rootDir = await tempMkdir('atom-fsmanager-test-');

      const watcher0 = await watchPath(rootDir, {}, () => {});
      const watcher1 = await watchPath(rootDir, {}, () => {});

      expect(watcher0.native).toBe(watcher1.native);
    });

    it("reuses existing native watchers even while they're still starting", async function() {
      const rootDir = await tempMkdir('atom-fsmanager-test-');

      const [watcher0, watcher1] = await Promise.all([
        watchPath(rootDir, {}, () => {}),
        watchPath(rootDir, {}, () => {})
      ]);
      expect(watcher0.native).toBe(watcher1.native);
    });

    it("doesn't attach new watchers to a native watcher that's stopping", async function() {
      const rootDir = await tempMkdir('atom-fsmanager-test-');

      const watcher0 = await watchPath(rootDir, {}, () => {});
      const native0 = watcher0.native;

      watcher0.dispose();
      const watcher1 = await watchPath(rootDir, {}, () => {});

      expect(watcher1.native).not.toBe(native0);
    });

    it('reuses an existing native watcher on a parent directory and filters events', async function() {
      const rootDir = await tempMkdir('atom-fsmanager-test-').then(realpath);
      const rootFile = path.join(rootDir, 'rootfile.txt');
      const subDir = path.join(rootDir, 'subdir');
      const subFile = path.join(subDir, 'subfile.txt');

      await mkdir(subDir);

      // Keep the watchers alive with an undisposed subscription
      const rootWatcher = await watchPath(rootDir, {}, () => {});
      const childWatcher = await watchPath(subDir, {}, () => {});

      expect(rootWatcher.native).toBe(childWatcher.native);
      expect(rootWatcher.native.isRunning()).toBe(true);

      const firstChanges = Promise.all([
        waitForChanges(rootWatcher, subFile),
        waitForChanges(childWatcher, subFile)
      ]);
      await writeFile(subFile, 'subfile\n', { encoding: 'utf8' });
      await firstChanges;

      const nextRootEvent = waitForChanges(rootWatcher, rootFile);
      await writeFile(rootFile, 'rootfile\n', { encoding: 'utf8' });
      await nextRootEvent;
    });

    it('adopts existing child watchers and filters events appropriately to them', async function() {
      const parentDir = await tempMkdir('atom-fsmanager-test-').then(realpath);

      // Create the directory tree
      const rootFile = path.join(parentDir, 'rootfile.txt');
      const subDir0 = path.join(parentDir, 'subdir0');
      const subFile0 = path.join(subDir0, 'subfile0.txt');
      const subDir1 = path.join(parentDir, 'subdir1');
      const subFile1 = path.join(subDir1, 'subfile1.txt');

      await mkdir(subDir0);
      await mkdir(subDir1);
      await Promise.all([
        writeFile(rootFile, 'rootfile\n', { encoding: 'utf8' }),
        writeFile(subFile0, 'subfile 0\n', { encoding: 'utf8' }),
        writeFile(subFile1, 'subfile 1\n', { encoding: 'utf8' })
      ]);

      // Begin the child watchers and keep them alive
      const subWatcher0 = await watchPath(subDir0, {}, () => {});
      const subWatcherChanges0 = waitForChanges(subWatcher0, subFile0);

      const subWatcher1 = await watchPath(subDir1, {}, () => {});
      const subWatcherChanges1 = waitForChanges(subWatcher1, subFile1);

      expect(subWatcher0.native).not.toBe(subWatcher1.native);

      // Create the parent watcher
      const parentWatcher = await watchPath(parentDir, {}, () => {});
      const parentWatcherChanges = waitForChanges(
        parentWatcher,
        rootFile,
        subFile0,
        subFile1
      );

      expect(subWatcher0.native).toBe(parentWatcher.native);
      expect(subWatcher1.native).toBe(parentWatcher.native);

      // Ensure events are filtered correctly
      await Promise.all([
        appendFile(rootFile, 'change\n', { encoding: 'utf8' }),
        appendFile(subFile0, 'change\n', { encoding: 'utf8' }),
        appendFile(subFile1, 'change\n', { encoding: 'utf8' })
      ]);

      await Promise.all([
        subWatcherChanges0,
        subWatcherChanges1,
        parentWatcherChanges
      ]);
    });
  });
});
