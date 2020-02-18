import fs from 'fs-extra';
import path from 'path';
import temp from 'temp';
import until from 'test-until';
import transpiler from '@atom/babel7-transpiler';

import React from 'react';
import ReactDom from 'react-dom';
import sinon from 'sinon';
import {Directory} from 'atom';
import {Emitter, CompositeDisposable, Disposable} from 'event-kit';

import Repository from '../lib/models/repository';
import GitShellOutStrategy from '../lib/git-shell-out-strategy';
import WorkerManager from '../lib/worker-manager';
import ContextMenuInterceptor from '../lib/context-menu-interceptor';
import getRepoPipelineManager from '../lib/get-repo-pipeline-manager';
import {clearRelayExpectations} from '../lib/relay-network-layer-manager';
import FileSystemChangeObserver from '../lib/models/file-system-change-observer';

assert.autocrlfEqual = (actual, expected, ...args) => {
  const newActual = actual.replace(/\r\n/g, '\n');
  const newExpected = expected.replace(/\r\n/g, '\n');
  return assert.equal(newActual, newExpected, ...args);
};

// cloning a repo into a folder and then copying it
// for each subsequent request to clone makes cloning
// 2-3x faster on macOS and 5-10x faster on Windows
const cachedClonedRepos = {};
async function copyCachedRepo(repoName) {
  const workingDirPath = temp.mkdirSync('git-fixture-');
  await fs.copy(cachedClonedRepos[repoName], workingDirPath);
  return fs.realpath(workingDirPath);
}

export const FAKE_USER = {
  email: 'nope@nah.com',
  name: 'Someone',
};

export async function cloneRepository(repoName = 'three-files') {
  if (!cachedClonedRepos[repoName]) {
    const cachedPath = temp.mkdirSync('git-fixture-cache-');
    const git = new GitShellOutStrategy(cachedPath);
    await git.clone(path.join(__dirname, 'fixtures', `repo-${repoName}`, 'dot-git'), {noLocal: true});
    await git.exec(['config', '--local', 'core.autocrlf', 'false']);
    await git.exec(['config', '--local', 'commit.gpgsign', 'false']);
    await git.exec(['config', '--local', 'user.email', FAKE_USER.email]);
    await git.exec(['config', '--local', 'user.name', FAKE_USER.name]);
    await git.exec(['config', '--local', 'push.default', 'simple']);
    await git.exec(['checkout', '--', '.']); // discard \r in working directory
    cachedClonedRepos[repoName] = cachedPath;
  }
  return copyCachedRepo(repoName);
}

export async function sha(directory) {
  const git = new GitShellOutStrategy(directory);
  const head = await git.getHeadCommit();
  return head.sha;
}

/*
 * Initialize an empty repository at a temporary path.
 */
export async function initRepository() {
  const workingDirPath = temp.mkdirSync('git-fixture-');
  const git = new GitShellOutStrategy(workingDirPath);
  await git.exec(['init']);
  await git.exec(['config', '--local', 'user.email', FAKE_USER.email]);
  await git.exec(['config', '--local', 'user.name', FAKE_USER.name]);
  await git.exec(['config', '--local', 'core.autocrlf', 'false']);
  await git.exec(['config', '--local', 'commit.gpgsign', 'false']);
  return fs.realpath(workingDirPath);
}

export async function setUpLocalAndRemoteRepositories(repoName = 'multiple-commits', options = {}) {

  if (typeof repoName === 'object') {
    options = repoName;
    repoName = 'multiple-commits';
  }

  const baseRepoPath = await cloneRepository(repoName);
  const baseGit = new GitShellOutStrategy(baseRepoPath);

  // create remote bare repo with all commits
  const remoteRepoPath = temp.mkdirSync('git-remote-fixture-');
  const remoteGit = new GitShellOutStrategy(remoteRepoPath);
  await remoteGit.clone(baseRepoPath, {noLocal: true, bare: true});

  // create local repo with one fewer commit
  if (options.remoteAhead) { await baseGit.exec(['reset', 'HEAD~']); }
  const localRepoPath = temp.mkdirSync('git-local-fixture-');
  const localGit = new GitShellOutStrategy(localRepoPath);
  await localGit.clone(baseRepoPath, {noLocal: true});
  await localGit.exec(['remote', 'set-url', 'origin', remoteRepoPath]);
  await localGit.exec(['config', '--local', 'commit.gpgsign', 'false']);
  await localGit.exec(['config', '--local', 'user.email', FAKE_USER.email]);
  await localGit.exec(['config', '--local', 'user.name', FAKE_USER.name]);
  await localGit.exec(['config', '--local', 'pull.rebase', false]);
  return {baseRepoPath, remoteRepoPath, localRepoPath};
}

export async function getHeadCommitOnRemote(remotePath) {
  const workingDirPath = temp.mkdirSync('git-fixture-');
  const git = new GitShellOutStrategy(workingDirPath);
  await git.clone(remotePath, {noLocal: true});
  return git.getHeadCommit();
}

export async function buildRepository(workingDirPath, options) {
  const repository = new Repository(workingDirPath, null, options);
  await repository.getLoadPromise();
  // eslint-disable-next-line jasmine/no-global-setup
  afterEach(async () => {
    const repo = await repository;
    repo && repo.destroy();
  });
  return repository;
}

export function buildRepositoryWithPipeline(workingDirPath, options) {
  const pipelineManager = getRepoPipelineManager(options);
  return buildRepository(workingDirPath, {pipelineManager});
}

// Custom assertions

export function assertDeepPropertyVals(actual, expected) {
  function extractObjectSubset(actualValue, expectedValue) {
    if (actualValue !== Object(actualValue)) { return actualValue; }

    const actualSubset = Array.isArray(actualValue) ? [] : {};
    for (const key of Object.keys(expectedValue)) {
      if (actualValue.hasOwnProperty(key)) {
        actualSubset[key] = extractObjectSubset(actualValue[key], expectedValue[key]);
      }
    }

    return actualSubset;
  }

  assert.deepEqual(extractObjectSubset(actual, expected), expected);
}

export function assertEqualSets(a, b) {
  assert.equal(a.size, b.size, 'Sets are a different size');
  a.forEach(item => assert(b.has(item), 'Sets have different elements'));
}

export function assertEqualSortedArraysByKey(arr1, arr2, key) {
  const sortFn = (a, b) => a[key] < b[key];
  assert.deepEqual(arr1.sort(sortFn), arr2.sort(sortFn));
}

// Helpers for test/models/patch classes

class PatchBufferAssertions {
  constructor(patch, buffer) {
    this.patch = patch;
    this.buffer = buffer;
  }

  hunk(hunkIndex, {startRow, endRow, header, regions}) {
    const hunk = this.patch.getHunks()[hunkIndex];
    assert.isDefined(hunk);

    assert.strictEqual(hunk.getRange().start.row, startRow);
    assert.strictEqual(hunk.getRange().end.row, endRow);
    assert.strictEqual(hunk.getHeader(), header);
    assert.lengthOf(hunk.getRegions(), regions.length);

    for (let i = 0; i < regions.length; i++) {
      const region = hunk.getRegions()[i];
      const spec = regions[i];

      assert.strictEqual(region.constructor.name.toLowerCase(), spec.kind);
      assert.strictEqual(region.toStringIn(this.buffer), spec.string);
      assert.deepEqual(region.getRange().serialize(), spec.range);
    }
  }

  hunks(...specs) {
    assert.lengthOf(this.patch.getHunks(), specs.length);
    for (let i = 0; i < specs.length; i++) {
      this.hunk(i, specs[i]);
    }
  }
}

export function assertInPatch(patch, buffer) {
  return new PatchBufferAssertions(patch, buffer);
}

export function assertInFilePatch(filePatch, buffer) {
  return assertInPatch(filePatch.getPatch(), buffer);
}

export function assertMarkerRanges(markerLayer, ...expectedRanges) {
  const bufferLayer = markerLayer.bufferMarkerLayer || markerLayer;
  const actualRanges = bufferLayer.getMarkers().map(m => m.getRange().serialize());
  assert.deepEqual(actualRanges, expectedRanges);
}

let activeRenderers = [];
export function createRenderer() {
  let instance;
  let lastInstance;
  let node = document.createElement('div');
  // ref function should be reference equal over renders to avoid React
  // calling the "old" one with `null` and the "new" one with the instance
  const setTopLevelRef = c => { instance = c; };
  const renderer = {
    render(appWithoutRef) {
      lastInstance = instance;
      const app = React.cloneElement(appWithoutRef, {ref: setTopLevelRef});
      ReactDom.render(app, node);
    },

    get instance() {
      return instance;
    },

    get lastInstance() {
      return lastInstance;
    },

    get node() {
      return node;
    },

    unmount() {
      if (node) {
        lastInstance = instance;
        ReactDom.unmountComponentAtNode(node);
        node = null;
      }
    },
  };
  activeRenderers.push(renderer);
  return renderer;
}

export function isProcessAlive(pid) {
  if (typeof pid !== 'number') {
    throw new Error(`PID must be a number. Got ${pid}`);
  }
  let alive = true;
  try {
    return process.kill(pid, 0);
  } catch (e) {
    alive = false;
  }
  return alive;
}

class UnwatchedDirectory extends Directory {
  onDidChangeFiles(callback) {
    return {dispose: () => {}};
  }
}

export async function disableFilesystemWatchers(atomEnv) {
  atomEnv.packages.serviceHub.provide('atom.directory-provider', '0.1.0', {
    directoryForURISync(uri) {
      return new UnwatchedDirectory(uri);
    },
  });

  await until('directoryProvider is available', () => atomEnv.project.directoryProviders.length > 0);
}

const packageRoot = path.resolve(__dirname, '..');
const transpiledRoot = path.resolve(__dirname, 'output/transpiled/');

export function transpile(...relPaths) {
  return Promise.all(
    relPaths.map(async relPath => {
      const untranspiledPath = path.resolve(__dirname, '..', relPath);
      const transpiledPath = path.join(transpiledRoot, path.relative(packageRoot, untranspiledPath));

      const untranspiledSource = await fs.readFile(untranspiledPath, {encoding: 'utf8'});
      const transpiledSource = transpiler.transpile(untranspiledSource, untranspiledPath, {}, {}).code;

      await fs.mkdirs(path.dirname(transpiledPath));
      await fs.writeFile(transpiledPath, transpiledSource, {encoding: 'utf8'});
      return transpiledPath;
    }),
  );
}

// Manually defer the next setState() call performed on a React component instance until a returned resolution method
// is called. This is useful for testing code paths that will only be triggered if a setState call is asynchronous,
// which React can choose to do at any time, but Enzyme will never do on its own.
//
// This function will also return a pair of Promises which will be resolved when the stubbed setState call has begun
// and when it has completed. Be sure to await the `started` Promise before calling `deferSetState` again.
//
// Examples:
//
// ```
// const {resolve} = deferSetState(wrapper.instance());
// wrapper.instance().doStateChange();
// assert.isFalse(wrapper.update().find('Child').prop('changed'));
// resolve();
// assert.isTrue(wrapper.update().find('Child').prop('changed'));
// ```
//
// ```
// const {resolve: resolve0, started: started0} = deferSetState(wrapper.instance());
// /* ... */
// await started0;
// const {resolve: resolve1} = deferSetState(wrapper.instance());
// /* ... */
// resolve1();
// resolve0();
// ```
export function deferSetState(instance) {
  if (!instance.__deferOriginalSetState) {
    instance.__deferOriginalSetState = instance.setState;
  }
  let resolve, resolveStarted, resolveCompleted;
  const started = new Promise(r => { resolveStarted = r; });
  const completed = new Promise(r => { resolveCompleted = r; });
  const resolved = new Promise(r => { resolve = r; });

  const stub = function(updater, callback) {
    resolveStarted();
    resolved.then(() => {
      instance.__deferOriginalSetState(updater, () => {
        if (callback) {
          callback();
        }
        resolveCompleted();
      });
    });
  };
  instance.setState = stub;

  return {resolve, started, completed};
}

// eslint-disable-next-line jasmine/no-global-setup
beforeEach(function() {
  global.sinon = sinon.createSandbox();
});

// eslint-disable-next-line jasmine/no-global-setup
afterEach(function() {
  activeRenderers.forEach(r => r.unmount());
  activeRenderers = [];

  ContextMenuInterceptor.dispose();

  global.sinon.restore();

  clearRelayExpectations();
});

// eslint-disable-next-line jasmine/no-global-setup
after(() => {
  if (!process.env.ATOM_GITHUB_SHOW_RENDERER_WINDOW) {
    WorkerManager.reset(true);
  }

  if (global._nyc) {
    global._nyc.writeCoverageFile();

    if (global._nycInProcess) {
      global._nyc.report();
    }
  }
});

export class ManualStateObserver {
  constructor() {
    this.emitter = new Emitter();
  }

  onDidComplete(callback) {
    return this.emitter.on('did-complete', callback);
  }

  trigger() {
    this.emitter.emit('did-complete');
  }

  dispose() {
    this.emitter.dispose();
  }
}


// File system event helpers
let observedEvents, eventCallback;

export async function wireUpObserver(fixtureName = 'multi-commits-files', existingWorkdir = null) {
  observedEvents = [];
  eventCallback = () => {};

  const workdir = existingWorkdir || await cloneRepository(fixtureName);
  const repository = new Repository(workdir);
  await repository.getLoadPromise();

  const observer = new FileSystemChangeObserver(repository);

  const subscriptions = new CompositeDisposable(
    new Disposable(async () => {
      await observer.destroy();
      repository.destroy();
    }),
  );

  subscriptions.add(observer.onDidChange(events => {
    observedEvents.push(...events);
    eventCallback();
  }));

  return {repository, observer, subscriptions};
}

export function expectEvents(repository, ...suffixes) {
  const pending = new Set(suffixes);
  return new Promise((resolve, reject) => {
    eventCallback = () => {
      const matchingPaths = observedEvents
        .filter(event => {
          for (const suffix of pending) {
            if (event.path.endsWith(suffix)) {
              pending.delete(suffix);
              return true;
            }
          }
          return false;
        });

      if (matchingPaths.length > 0) {
        repository.observeFilesystemChange(matchingPaths);
      }

      if (pending.size === 0) {
        resolve();
      }
    };

    if (observedEvents.length > 0) {
      eventCallback();
    }
  });
}

// Atom environment utilities

// Ensure the Workspace doesn't mangle atom-github://... URIs.
// If you don't have an opener registered for a non-standard URI protocol, the Workspace coerces it into a file URI
// and tries to open it with a TextEditor. In the process, the URI gets mangled:
//
// atom.workspace.open('atom-github://unknown/whatever').then(item => console.log(item.getURI()))
// > 'atom-github:/unknown/whatever'
//
// Adding an opener that creates fake items prevents it from doing this and keeps the URIs unchanged.
export function registerGitHubOpener(atomEnv) {
  atomEnv.workspace.addOpener(uri => {
    if (uri.startsWith('atom-github://')) {
      return {
        getURI() { return uri; },

        getElement() {
          if (!this.element) {
            this.element = document.createElement('div');
          }
          return this.element;
        },
      };
    } else {
      return undefined;
    }
  });
}
