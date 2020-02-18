import BranchSet from '../../lib/models/branch-set';
import Branch, {nullBranch} from '../../lib/models/branch';

describe('BranchSet', function() {
  it('earmarks HEAD', function() {
    const bs = new BranchSet();
    bs.add(new Branch('foo'));
    bs.add(new Branch('bar', Branch.createRemoteTracking('upstream/bar', 'upstream', 'refs/heads/bar')));

    const current = new Branch('currentBranch', nullBranch, nullBranch, true);
    bs.add(current);

    assert.strictEqual(current, bs.getHeadBranch());
  });

  it('returns a nullBranch if no ref is HEAD', function() {
    const bs = new BranchSet();
    bs.add(new Branch('foo'));
    bs.add(new Branch('bar', Branch.createRemoteTracking('upstream/bar', 'upstream', 'refs/heads/bar')));

    assert.isFalse(bs.getHeadBranch().isPresent());
  });

  describe('getPullTargets() and getPushSources()', function() {
    let bs, bar, baz, boo, sharedUpPush, sharedUp, sharedPush;

    beforeEach(function() {
      bs = new BranchSet();

      // A branch with no upstream or push target
      bs.add(new Branch('foo'));

      // A branch with a consistent upstream and push
      bar = new Branch('bar', Branch.createRemoteTracking('upstream/bar', 'upstream', 'refs/heads/bar'));
      bs.add(bar);

      // A branch with an upstream and push that use some weird-ass refspec
      baz = new Branch('baz', Branch.createRemoteTracking('origin/baz', 'origin', 'refs/heads/remotes/wat/boop'));
      bs.add(baz);

      // A branch with an upstream and push that differ
      boo = new Branch(
        'boo',
        Branch.createRemoteTracking('upstream/boo', 'upstream', 'refs/heads/fetch-from-here'),
        Branch.createRemoteTracking('origin/boo', 'origin', 'refs/heads/push-to-here'),
      );
      bs.add(boo);

      // Branches that fetch and push to the same remote ref as other branches
      sharedUpPush = new Branch(
        'shared/up/push',
        Branch.createRemoteTracking('upstream/shared/up/push', 'upstream', 'refs/heads/shared/up'),
        Branch.createRemoteTracking('origin/shared/up/push', 'origin', 'refs/heads/shared/push'),
      );
      bs.add(sharedUpPush);

      sharedUp = new Branch(
        'shared/up',
        Branch.createRemoteTracking('upstream/shared/up', 'upstream', 'refs/heads/shared/up'),
      );
      bs.add(sharedUp);

      sharedPush = new Branch(
        'shared/push',
        Branch.createRemoteTracking('origin/shared/push', 'origin', 'refs/heads/shared/push'),
      );
      bs.add(sharedPush);
    });

    it('returns empty results for an unknown remote', function() {
      assert.lengthOf(bs.getPullTargets('unknown', 'refs/heads/bar'), 0);
      assert.lengthOf(bs.getPushSources('unknown', 'refs/heads/bar'), 0);
    });

    it('returns empty results for an unknown ref', function() {
      assert.lengthOf(bs.getPullTargets('upstream', 'refs/heads/unknown'), 0);
      assert.lengthOf(bs.getPushSources('origin', 'refs/heads/unknown'), 0);
    });

    it('locates branches that fetch from a remote ref', function() {
      assert.deepEqual(bs.getPullTargets('upstream', 'refs/heads/bar'), [bar]);
    });

    it('locates multiple branches that fetch from the same ref', function() {
      assert.sameMembers(bs.getPullTargets('upstream', 'refs/heads/shared/up'), [sharedUpPush, sharedUp]);
    });

    it('locates branches that push to a remote ref', function() {
      assert.deepEqual(bs.getPushSources('origin', 'refs/heads/push-to-here'), [boo]);
    });

    it('locates multiple branches that push to the same ref', function() {
      assert.sameMembers(bs.getPushSources('origin', 'refs/heads/shared/push'), [sharedUpPush, sharedPush]);
    });
  });
});
