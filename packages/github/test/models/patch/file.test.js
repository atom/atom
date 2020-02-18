import File, {nullFile} from '../../../lib/models/patch/file';

describe('File', function() {
  it("detects when it's a symlink", function() {
    assert.isTrue(new File({path: 'path', mode: '120000', symlink: null}).isSymlink());
    assert.isFalse(new File({path: 'path', mode: '100644', symlink: null}).isSymlink());
    assert.isFalse(nullFile.isSymlink());
  });

  it("detects when it's a regular file", function() {
    assert.isTrue(new File({path: 'path', mode: '100644', symlink: null}).isRegularFile());
    assert.isTrue(new File({path: 'path', mode: '100755', symlink: null}).isRegularFile());
    assert.isFalse(new File({path: 'path', mode: '120000', symlink: null}).isRegularFile());
    assert.isFalse(nullFile.isRegularFile());
  });

  it("detects when it's executable", function() {
    assert.isTrue(new File({path: 'path', mode: '100755', symlink: null}).isExecutable());
    assert.isFalse(new File({path: 'path', mode: '100644', symlink: null}).isExecutable());
    assert.isFalse(new File({path: 'path', mode: '120000', symlink: null}).isExecutable());
    assert.isFalse(nullFile.isExecutable());
  });

  it('clones itself with possible overrides', function() {
    const original = new File({path: 'original', mode: '100644', symlink: null});

    const dup0 = original.clone();
    assert.notStrictEqual(original, dup0);
    assert.strictEqual(dup0.getPath(), 'original');
    assert.strictEqual(dup0.getMode(), '100644');
    assert.isNull(dup0.getSymlink());

    const dup1 = original.clone({path: 'replaced'});
    assert.notStrictEqual(original, dup1);
    assert.strictEqual(dup1.getPath(), 'replaced');
    assert.strictEqual(dup1.getMode(), '100644');
    assert.isNull(dup1.getSymlink());

    const dup2 = original.clone({mode: '100755'});
    assert.notStrictEqual(original, dup2);
    assert.strictEqual(dup2.getPath(), 'original');
    assert.strictEqual(dup2.getMode(), '100755');
    assert.isNull(dup2.getSymlink());

    const dup3 = original.clone({mode: '120000', symlink: 'destination'});
    assert.notStrictEqual(original, dup3);
    assert.strictEqual(dup3.getPath(), 'original');
    assert.strictEqual(dup3.getMode(), '120000');
    assert.strictEqual(dup3.getSymlink(), 'destination');
  });

  it('clones the null file as itself', function() {
    const dup = nullFile.clone();
    assert.strictEqual(dup, nullFile);
    assert.isFalse(dup.isPresent());
  });

  it('clones the null file with new properties', function() {
    const dup0 = nullFile.clone({path: 'replaced'});
    assert.notStrictEqual(nullFile, dup0);
    assert.strictEqual(dup0.getPath(), 'replaced');
    assert.isNull(dup0.getMode());
    assert.isNull(dup0.getSymlink());
    assert.isTrue(dup0.isPresent());

    const dup1 = nullFile.clone({mode: '120000'});
    assert.notStrictEqual(nullFile, dup1);
    assert.isNull(dup1.getPath());
    assert.strictEqual(dup1.getMode(), '120000');
    assert.isNull(dup1.getSymlink());
    assert.isTrue(dup1.isPresent());

    const dup2 = nullFile.clone({symlink: 'target'});
    assert.notStrictEqual(nullFile, dup2);
    assert.isNull(dup2.getPath());
    assert.isNull(dup2.getMode());
    assert.strictEqual(dup2.getSymlink(), 'target');
    assert.isTrue(dup2.isPresent());
  });
});
