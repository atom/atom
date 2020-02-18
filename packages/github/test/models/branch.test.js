import Branch, {nullBranch} from '../../lib/models/branch';
import util from 'util';

describe('Branch', function() {
  it('creates a branch with no upstream', function() {
    const b = new Branch('feature');
    assert.strictEqual(b.getName(), 'feature');
    assert.strictEqual(b.getShortRef(), 'feature');
    assert.strictEqual(b.getFullRef(), 'refs/heads/feature');
    assert.strictEqual(b.getRemoteName(), '');
    assert.strictEqual(b.getRemoteRef(), '');
    assert.strictEqual(b.getShortRemoteRef(), '');
    assert.strictEqual(b.getSha(), '');
    assert.isFalse(b.getUpstream().isPresent());
    assert.isFalse(b.getPush().isPresent());
    assert.isFalse(b.isHead());
    assert.isFalse(b.isDetached());
    assert.isFalse(b.isRemoteTracking());
    assert.isTrue(b.isPresent());
  });

  it('creates a branch with an upstream', function() {
    const upstream = new Branch('upstream');
    const b = new Branch('feature', upstream);
    assert.strictEqual(b.getUpstream(), upstream);
    assert.strictEqual(b.getPush(), upstream);
  });

  it('creates a branch with separate upstream and push destinations', function() {
    const upstream = new Branch('upstream');
    const push = new Branch('push');
    const b = new Branch('feature', upstream, push);
    assert.strictEqual(b.getUpstream(), upstream);
    assert.strictEqual(b.getPush(), push);
  });

  it('creates a head branch', function() {
    const b = new Branch('current', nullBranch, nullBranch, true);
    assert.isTrue(b.isHead());
  });

  it('creates a detached branch', function() {
    const b = Branch.createDetached('master~2');
    assert.isTrue(b.isDetached());
    assert.strictEqual(b.getFullRef(), '');
  });

  it('creates a remote tracking branch', function() {
    const b = Branch.createRemoteTracking('refs/remotes/origin/feature', 'origin', 'refs/heads/feature');
    assert.isTrue(b.isRemoteTracking());
    assert.strictEqual(b.getFullRef(), 'refs/remotes/origin/feature');
    assert.strictEqual(b.getShortRemoteRef(), 'feature');
    assert.strictEqual(b.getRemoteName(), 'origin');
    assert.strictEqual(b.getRemoteRef(), 'refs/heads/feature');
  });

  it('getShortRef() truncates the refs/<type> prefix from a ref', function() {
    assert.strictEqual(new Branch('refs/heads/feature').getShortRef(), 'feature');
    assert.strictEqual(new Branch('heads/feature').getShortRef(), 'feature');
    assert.strictEqual(new Branch('feature').getShortRef(), 'feature');
  });

  it('getFullRef() reconstructs the full ref name', function() {
    assert.strictEqual(new Branch('refs/heads/feature').getFullRef(), 'refs/heads/feature');
    assert.strictEqual(new Branch('heads/feature').getFullRef(), 'refs/heads/feature');
    assert.strictEqual(new Branch('feature').getFullRef(), 'refs/heads/feature');

    const r0 = Branch.createRemoteTracking('refs/remotes/origin/feature', 'origin', 'refs/heads/feature');
    assert.strictEqual(r0.getFullRef(), 'refs/remotes/origin/feature');
    const r1 = Branch.createRemoteTracking('remotes/origin/feature', 'origin', 'refs/heads/feature');
    assert.strictEqual(r1.getFullRef(), 'refs/remotes/origin/feature');
    const r2 = Branch.createRemoteTracking('origin/feature', 'origin', 'refs/heads/feature');
    assert.strictEqual(r2.getFullRef(), 'refs/remotes/origin/feature');
  });

  it('getRemoteName() returns the name of a remote', function() {
    assert.strictEqual(
      Branch.createRemoteTracking('origin/master', 'origin', 'refs/heads/master').getRemoteName(),
      'origin',
    );
    assert.strictEqual(
      Branch.createRemoteTracking('origin/master', undefined, 'refs/heads/master').getRemoteName(),
      '',
    );
  });

  it('getRemoteRef() returns the name of the remote ref', function() {
    assert.strictEqual(
      Branch.createRemoteTracking('origin/master', 'origin', 'refs/heads/master').getRemoteRef(),
      'refs/heads/master',
    );
    assert.strictEqual(
      Branch.createRemoteTracking('origin/master', 'origin', undefined).getRemoteRef(),
      '',
    );
  });

  it('has a null object', function() {
    for (const method of [
      'getName', 'getFullRef', 'getShortRef', 'getSha', 'getRemoteName', 'getRemoteRef', 'getShortRemoteRef',
    ]) {
      assert.strictEqual(nullBranch[method](), '');
    }

    assert.strictEqual(nullBranch.getUpstream(), nullBranch);
    assert.strictEqual(nullBranch.getPush(), nullBranch);

    for (const method of ['isHead', 'isDetached', 'isRemoteTracking', 'isPresent']) {
      assert.isFalse(nullBranch[method]());
    }

    assert.strictEqual(util.inspect(nullBranch), '{nullBranch}');
  });
});
