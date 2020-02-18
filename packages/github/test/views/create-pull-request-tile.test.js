import React from 'react';
import {shallow} from 'enzyme';

import CreatePullRequestTile from '../../lib/views/create-pull-request-tile';
import Remote from '../../lib/models/remote';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';

describe('CreatePullRequestTile', function() {
  function buildApp(overrides = {}) {
    const repository = {
      defaultBranchRef: {
        prefix: 'refs/heads',
        name: 'master',
      },
    };

    const branches = new BranchSet([
      new Branch('feature', nullBranch, nullBranch, true),
    ]);

    return (
      <CreatePullRequestTile
        repository={repository}
        remote={new Remote('origin', 'git@github.com:atom/github.git')}
        branches={branches}
        aheadCount={0}
        pushInProgress={false}
        onCreatePr={() => {}}
        {...overrides}
      />
    );
  }

  describe('static messages', function() {
    it('reports a repository that is no longer found', function() {
      const wrapper = shallow(buildApp({
        repository: null,
      }));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'Repository not found',
      );
    });

    it('reports a detached HEAD', function() {
      const branches = new BranchSet([new Branch('other')]);
      const wrapper = shallow(buildApp({branches}));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'any branch',
      );
    });

    it('reports when the remote repository has no default branch', function() {
      const wrapper = shallow(buildApp({
        repository: {
          defaultBranchRef: null,
        },
      }));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'empty',
      );
    });

    it('reports when you are still on the default ref', function() {
      // The destination ref of HEAD's *push* target is used to determine whether or not you're on the default ref
      const branches = new BranchSet([
        new Branch(
          'current',
          nullBranch,
          Branch.createRemoteTracking('refs/remotes/origin/current', 'origin', 'refs/heads/whatever'),
          true,
        ),
      ]);
      const repository = {
        defaultBranchRef: {
          prefix: 'refs/heads/',
          name: 'whatever',
        },
      };
      const wrapper = shallow(buildApp({branches, repository}));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'default branch',
      );
    });

    it('reports when HEAD has not moved from the default ref', function() {
      const branches = new BranchSet([
        new Branch(
          'current',
          nullBranch,
          Branch.createRemoteTracking('refs/remotes/origin/current', 'origin', 'refs/heads/whatever'),
          true,
          {sha: '1234'},
        ),
        new Branch(
          'pushes-to-main',
          nullBranch,
          Branch.createRemoteTracking('refs/remotes/origin/main', 'origin', 'refs/heads/main'),
          false,
          {sha: '1234'},
        ),
        new Branch(
          'pushes-to-main-2',
          nullBranch,
          Branch.createRemoteTracking('refs/remotes/origin/main', 'origin', 'refs/heads/main'),
          false,
          {sha: '5678'},
        ),
      ]);
      const repository = {
        defaultBranchRef: {
          prefix: 'refs/heads/',
          name: 'main',
        },
      };
      const wrapper = shallow(buildApp({branches, repository}));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'has not moved',
      );
    });
  });

  describe('pushing or publishing a branch', function() {
    let repository, branches;

    beforeEach(function() {
      repository = {
        defaultBranchRef: {
          prefix: 'refs/heads/',
          name: 'master',
        },
      };

      const masterTracking = Branch.createRemoteTracking('refs/remotes/origin/current', 'origin', 'refs/heads/current');
      branches = new BranchSet([
        new Branch('current', masterTracking, masterTracking, true),
      ]);
    });

    it('disables the button while a push is in progress', function() {
      const wrapper = shallow(buildApp({
        repository,
        branches,
        pushInProgress: true,
      }));

      assert.strictEqual(wrapper.find('.github-CreatePullRequestTile-createPr').text(), 'Pushing...');
      assert.isTrue(wrapper.find('.github-CreatePullRequestTile-createPr').prop('disabled'));
    });

    it('prompts to publish with no upstream', function() {
      branches = new BranchSet([
        new Branch('current', nullBranch, nullBranch, true),
      ]);
      const wrapper = shallow(buildApp({
        repository,
        branches,
      }));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-createPr').text(),
        'Publish + open new pull request',
      );
      assert.isFalse(wrapper.find('.github-CreatePullRequestTile-createPr').prop('disabled'));
    });

    it('prompts to publish with an upstream on a different remote', function() {
      const onDifferentRemote = Branch.createRemoteTracking(
        'refs/remotes/upstream/current', 'upstream', 'refs/heads/current');
      branches = new BranchSet([
        new Branch('current', nullBranch, onDifferentRemote, true),
      ]);
      const wrapper = shallow(buildApp({
        repository,
        branches,
      }));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-message strong').at(0).text(),
        'configured',
      );

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-createPr').text(),
        'Publish + open new pull request',
      );
      assert.isFalse(wrapper.find('.github-CreatePullRequestTile-createPr').prop('disabled'));
    });

    it('prompts to push when the local ref is ahead', function() {
      const wrapper = shallow(buildApp({
        repository,
        branches,
        aheadCount: 10,
      }));

      assert.strictEqual(
        wrapper.find('.github-CreatePullRequestTile-createPr').text(),
        'Push + open new pull request',
      );
      assert.isFalse(wrapper.find('.github-CreatePullRequestTile-createPr').prop('disabled'));
    });

    it('falls back to prompting to open the PR', function() {
      const wrapper = shallow(buildApp({repository, branches}));

      assert.strictEqual(wrapper.find('.github-CreatePullRequestTile-createPr').text(), 'Open new pull request');
      assert.isFalse(wrapper.find('.github-CreatePullRequestTile-createPr').prop('disabled'));
    });
  });
});
