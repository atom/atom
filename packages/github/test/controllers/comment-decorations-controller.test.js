import React from 'react';
import {mount, shallow} from 'enzyme';
import path from 'path';
import fs from 'fs-extra';

import {BareCommentDecorationsController} from '../../lib/controllers/comment-decorations-controller';
import RelayNetworkLayerManager from '../../lib/relay-network-layer-manager';
import ReviewsItem from '../../lib/items/reviews-item';
import {aggregatedReviewsBuilder} from '../builder/graphql/aggregated-reviews-builder';
import {getEndpoint} from '../../lib/models/endpoint';
import pullRequestsQuery from '../../lib/controllers/__generated__/commentDecorationsController_pullRequests.graphql';
import {pullRequestBuilder} from '../builder/graphql/pr';
import Branch from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';

describe('CommentDecorationsController', function() {
  let atomEnv, relayEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    relayEnv = RelayNetworkLayerManager.getEnvironmentForHost(getEndpoint('github.com'), '1234');
  });

  afterEach(async function() {
    atomEnv.destroy();
    await fs.remove(path.join(__dirname, 'file0.txt'));
  });

  function buildApp(override = {}) {
    const origin = new Remote('origin', 'git@github.com:owner/repo.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/origin/featureBranch', 'origin', 'refs/heads/featureBranch');
    const branch = new Branch('featureBranch', upstreamBranch, upstreamBranch, true);
    const {commentThreads} = aggregatedReviewsBuilder()
      .addReviewThread(t => {
        t.addComment(c => c.id('0').path('file0.txt').position(2).bodyHTML('one'));
      })
      .addReviewThread(t => {
        t.addComment(c => c.id('1').path('file1.txt').position(15).bodyHTML('two'));
      })
      .addReviewThread(t => {
        t.addComment(c => c.id('2').path('file2.txt').position(7).bodyHTML('three'));
      })
      .addReviewThread(t => {
        t.addComment(c => c.id('3').path('file2.txt').position(10).bodyHTML('four'));
      })
      .build();

    const pr = pullRequestBuilder(pullRequestsQuery)
      .number(100)
      .headRefName('featureBranch')
      .headRepository(r => {
        r.owner(o => o.login('owner'));
        r.name('repo');
      }).build();

    const props = {
      relay: {environment: relayEnv},
      pullRequests: [pr],
      repository: {},
      endpoint: getEndpoint('github.com'),
      owner: 'owner',
      repo: 'repo',
      commands: atomEnv.commands,
      workspace: atomEnv.workspace,
      repoData: {
        branches: new BranchSet([branch]),
        remotes: new RemoteSet([origin]),
        currentRemote: origin,
        workingDirectoryPath: __dirname,
      },
      commentThreads,
      commentTranslations: new Map(),
      updateCommentTranslations: () => {},
      ...override,
    };

    return <BareCommentDecorationsController {...props} />;
  }

  describe('renders EditorCommentDecorationsController and Gutter', function() {
    let editor0, editor1, editor2, wrapper;

    beforeEach(async function() {
      editor0 = await atomEnv.workspace.open(path.join(__dirname, 'file0.txt'));
      editor1 = await atomEnv.workspace.open(path.join(__dirname, 'another-unrelated-file.txt'));
      editor2 = await atomEnv.workspace.open(path.join(__dirname, 'file1.txt'));
      wrapper = mount(buildApp());
    });

    it('a pair per matching opened editor', function() {
      assert.strictEqual(wrapper.find('EditorCommentDecorationsController').length, 2);
      assert.isNotNull(editor0.gutterWithName('github-comment-icon'));
      assert.isNotNull(editor2.gutterWithName('github-comment-icon'));
      assert.isNull(editor1.gutterWithName('github-comment-icon'));
    });

    it('updates its EditorCommentDecorationsController and Gutter children as editor panes get created', async function() {
      editor2 = await atomEnv.workspace.open(path.join(__dirname, 'file2.txt'));
      wrapper.update();

      assert.strictEqual(wrapper.find('EditorCommentDecorationsController').length, 3);
      assert.isNotNull(editor2.gutterWithName('github-comment-icon'));
    });

    it('updates its EditorCommentDecorationsController and Gutter children as editor panes get destroyed', async function() {
      assert.strictEqual(wrapper.find('EditorCommentDecorationsController').length, 2);
      await atomEnv.workspace.getActivePaneItem().destroy();
      wrapper.update();

      assert.strictEqual(wrapper.find('EditorCommentDecorationsController').length, 1);

      wrapper.unmount();
    });
  });

  describe('returns empty render', function() {
    it('when PR is not checked out', async function() {
      await atomEnv.workspace.open(path.join(__dirname, 'file0.txt'));
      const pr = pullRequestBuilder(pullRequestsQuery)
        .headRefName('wrongBranch')
        .build();
      const wrapper = mount(buildApp({pullRequests: [pr]}));
      assert.isTrue(wrapper.isEmptyRender());
    });

    it('when a repository has been deleted', async function() {
      await atomEnv.workspace.open(path.join(__dirname, 'file0.txt'));
      const pr = pullRequestBuilder(pullRequestsQuery)
        .headRefName('featureBranch')
        .build();
      pr.headRepository = null;
      const wrapper = mount(buildApp({pullRequests: [pr]}));
      assert.isTrue(wrapper.isEmptyRender());
    });

    it('when there is no PR', async function() {
      await atomEnv.workspace.open(path.join(__dirname, 'file0.txt'));
      const wrapper = mount(buildApp({pullRequests: []}));
      assert.isTrue(wrapper.isEmptyRender());
    });
  });

  it('skips comment thread with only minimized comments', async function() {
    const {commentThreads} = aggregatedReviewsBuilder()
      .addReviewThread(t => {
        t.addComment(c => c.id('0').path('file0.txt').position(2).bodyHTML('one').isMinimized(true));
        t.addComment(c => c.id('2').path('file0.txt').position(2).bodyHTML('two').isMinimized(true));
      })
      .addReviewThread(t => {
        t.addComment(c => c.id('1').path('file1.txt').position(15).bodyHTML('three'));
      })
      .build();
    await atomEnv.workspace.open(path.join(__dirname, 'file0.txt'));
    await atomEnv.workspace.open(path.join(__dirname, 'file1.txt'));
    const wrapper = mount(buildApp({commentThreads}));
    assert.lengthOf(wrapper.find('EditorCommentDecorationsController'), 1);
    assert.strictEqual(
      wrapper.find('EditorCommentDecorationsController').prop('fileName'),
      path.join(__dirname, 'file1.txt'),
    );
  });

  describe('opening the reviews tab with a command', function() {
    it('opens the correct tab', function() {
      sinon.stub(atomEnv.workspace, 'open').returns();

      const wrapper = shallow(buildApp({
        endpoint: getEndpoint('github.enterprise.horse'),
        owner: 'me',
        repo: 'pushbot',
      }));

      const command = wrapper.find('Command[command="github:open-reviews-tab"]');
      command.prop('callback')();

      assert.isTrue(atomEnv.workspace.open.calledWith(
        ReviewsItem.buildURI({
          host: 'github.enterprise.horse',
          owner: 'me',
          repo: 'pushbot',
          number: 100,
          workdir: __dirname,
        }),
        {searchAllPanes: true},
      ));
    });
  });
});
