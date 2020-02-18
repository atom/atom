import path from 'path';
import temp from 'temp';
import fs from 'fs-extra';

import {cloneRepository} from '../helpers';

import WorkdirCache from '../../lib/models/workdir-cache';

describe('WorkdirCache', function() {
  let cache;

  beforeEach(function() {
    cache = new WorkdirCache(5);
  });

  it('defaults to 1000 entries', function() {
    assert.strictEqual((new WorkdirCache()).maxSize, 1000);
  });

  it('finds a workdir that is the given path', async function() {
    const sameDir = await cloneRepository('three-files');
    const workDir = await cache.find(sameDir);
    assert.equal(sameDir, workDir);
  });

  it("finds a workdir that's a parent of the given path", async function() {
    const expectedDir = await cloneRepository('three-files');
    const givenDir = path.join(expectedDir, 'subdir-1');
    const actualDir = await cache.find(givenDir);

    assert.equal(actualDir, expectedDir);
  });

  it('finds a workdir from within the .git directory', async function() {
    const expectedDir = await cloneRepository('three-files');
    const givenDir = path.join(expectedDir, '.git/hooks');
    const actualDir = await cache.find(givenDir);

    assert.strictEqual(actualDir, expectedDir);
  });

  it('finds a workdir from a gitdir file', async function() {
    const repoDir = await cloneRepository('three-files');
    const expectedDir = await fs.realpath(temp.mkdirSync());
    fs.writeFileSync(path.join(expectedDir, '.git'), `gitdir: ${path.join(repoDir, '.git')}`, 'utf8');
    const actualDir = await cache.find(expectedDir);

    assert.equal(actualDir, expectedDir);
  });

  it('returns null when a path is not in a git repository', async function() {
    const nonWorkdirPath = temp.mkdirSync();
    assert.isNull(await cache.find(nonWorkdirPath));
  });

  it('returns null when a path does not exist', async function() {
    const nope = path.join(
      __dirname,
      'does', 'not', 'exist', 'no', 'seriously', 'why', 'did', 'you', 'name', 'a', 'directory', 'this',
    );
    assert.isNull(await cache.find(nope));
  });

  it('understands a file path', async function() {
    const expectedDir = await cloneRepository('three-files');
    const givenFile = path.join(expectedDir, 'subdir-1', 'b.txt');
    const actualDir = await cache.find(givenFile);

    assert.equal(actualDir, expectedDir);
  });

  it('caches previously discovered results', async function() {
    const expectedDir = await cloneRepository('three-files');
    const givenDir = path.join(expectedDir, 'subdir-1');

    // Prime the cache
    await cache.find(givenDir);
    assert.isTrue(cache.known.has(givenDir));

    sinon.spy(cache, 'revParse');
    const actualDir = await cache.find(givenDir);
    assert.equal(actualDir, expectedDir);
    assert.isFalse(cache.revParse.called);
  });

  it('removes all cached entries', async function() {
    const [dir0, dir1] = await Promise.all([
      cloneRepository('three-files'),
      cloneRepository('three-files'),
    ]);

    const pathsToCheck = [
      dir0,
      path.join(dir0, 'a.txt'),
      path.join(dir0, 'subdir-1'),
      path.join(dir0, 'subdir-1', 'b.txt'),
      dir1,
    ];
    const expectedWorkdirs = [
      dir0, dir0, dir0, dir0, dir1,
    ];

    // Prime the cache
    const initial = await Promise.all(
      pathsToCheck.map(input => cache.find(input)),
    );
    assert.deepEqual(initial, expectedWorkdirs);

    // Re-lookup and hit the cache
    sinon.spy(cache, 'revParse');
    const relookup = await Promise.all(
      pathsToCheck.map(input => cache.find(input)),
    );
    assert.deepEqual(relookup, expectedWorkdirs);
    assert.equal(cache.revParse.callCount, 0);

    // Clear the cache
    await cache.invalidate();

    // Re-lookup and miss the cache
    const after = await Promise.all(
      pathsToCheck.map(input => cache.find(input)),
    );
    assert.deepEqual(after, expectedWorkdirs);
    assert.isTrue(cache.revParse.calledWith(dir0));
    assert.isTrue(cache.revParse.calledWith(path.join(dir0, 'a.txt')));
    assert.isTrue(cache.revParse.calledWith(path.join(dir0, 'subdir-1')));
    assert.isTrue(cache.revParse.calledWith(path.join(dir0, 'subdir-1', 'b.txt')));
    assert.isTrue(cache.revParse.calledWith(dir1));
  });

  it('clears the cache when the maximum size is exceeded', async function() {
    const dirs = await Promise.all(
      Array(6).fill(null, 0, 6).map(() => cloneRepository('three-files')),
    );

    await Promise.all(dirs.slice(0, 5).map(dir => cache.find(dir)));
    await cache.find(dirs[5]);

    const expectedDir = dirs[2];
    sinon.spy(cache, 'revParse');
    const actualDir = await cache.find(expectedDir);
    assert.strictEqual(actualDir, expectedDir);
    assert.isTrue(cache.revParse.called);
  });
});
