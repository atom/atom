import hock from 'hock';
import http from 'http';

import {setup, teardown} from './helpers';
import {PAGE_SIZE, CHECK_SUITE_PAGE_SIZE, CHECK_RUN_PAGE_SIZE} from '../../lib/helpers';
import {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import GitShellOutStrategy from '../../lib/git-shell-out-strategy';
import {relayResponseBuilder} from '../builder/graphql/query';

describe('integration: check out a pull request', function() {
  let context, wrapper, atomEnv, workspaceElement, git;
  let repositoryID, headRefID;

  function expectRepositoryQuery() {
    return expectRelayQuery({
      name: 'remoteContainerQuery',
      variables: {
        owner: 'owner',
        name: 'repo',
      },
    }, op => {
      return relayResponseBuilder(op)
        .repository(r => r.id(repositoryID))
        .build();
    });
  }

  function expectCurrentPullRequestQuery() {
    return expectRelayQuery({
      name: 'currentPullRequestContainerQuery',
      variables: {
        headOwner: 'owner',
        headName: 'repo',
        headRef: 'refs/heads/pr-head',
        first: 5,
        checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
        checkSuiteCursor: null,
        checkRunCount: CHECK_RUN_PAGE_SIZE,
        checkRunCursor: null,
      },
    }, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          r.id(repositoryID);
          r.ref(ref => ref.id(headRefID));
        })
        .build();
    });
  }

  function expectIssueishSearchQuery() {
    return expectRelayQuery({
      name: 'issueishSearchContainerQuery',
      variables: {
        query: 'repo:owner/repo type:pr state:open',
        first: 20,
        checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
        checkSuiteCursor: null,
        checkRunCount: CHECK_RUN_PAGE_SIZE,
        checkRunCursor: null,
      },
    }, op => {
      return relayResponseBuilder(op)
        .search(s => {
          s.issueCount(10);
          for (const n of [0, 1, 2]) {
            s.addNode(r => r.bePullRequest(pr => {
              pr.number(n);
              pr.commits(conn => conn.addNode());
            }));
          }
        })
        .build();
    });
  }

  function expectIssueishDetailQuery() {
    return expectRelayQuery({
      name: 'issueishDetailContainerQuery',
      variables: {
        repoOwner: 'owner',
        repoName: 'repo',
        issueishNumber: 1,
        timelineCount: PAGE_SIZE,
        timelineCursor: null,
        commitCount: PAGE_SIZE,
        commitCursor: null,
        reviewCount: PAGE_SIZE,
        reviewCursor: null,
        threadCount: PAGE_SIZE,
        threadCursor: null,
        commentCount: PAGE_SIZE,
        commentCursor: null,
        checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
        checkSuiteCursor: null,
        checkRunCount: CHECK_RUN_PAGE_SIZE,
        checkRunCursor: null,
      },
    }, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          r.id(repositoryID);
          r.name('repo');
          r.owner(o => o.login('owner'));
          r.issueish(b => {
            b.bePullRequest(pr => {
              pr.id('pr1');
            });
          });
          r.nullIssue();
          r.pullRequest(pr => {
            pr.id('pr1');
            pr.number(1);
            pr.title('Pull Request 1');
            pr.headRefName('pr-head');
            pr.headRepository(hr => {
              hr.name('repo');
              hr.owner(o => o.login('owner'));
            });
            pr.recentCommits(conn => conn.addEdge());
          });
        })
        .build();
    });
  }

  function expectMentionableUsersQuery() {
    return expectRelayQuery({
      name: 'GetMentionableUsers',
      variables: {
        owner: 'owner',
        name: 'repo',
        first: 100,
        after: null,
      },
    }, {
      repository: {
        mentionableUsers: {
          nodes: [{login: 'smashwilson', email: 'smashwilson@github.com', name: 'Me'}],
          pageInfo: {hasNextPage: false, endCursor: 'zzz'},
        },
      },
    });
  }

  function expectCommentDecorationsQuery() {
    return expectRelayQuery({
      name: 'commentDecorationsContainerQuery',
      variables: {
        headOwner: 'owner',
        headName: 'repo',
        headRef: 'refs/heads/pr-head',
        reviewCount: 50,
        reviewCursor: null,
        threadCount: 50,
        threadCursor: null,
        commentCount: 50,
        commentCursor: null,
        first: 1,
      },
    }, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          r.id(repositoryID);
          r.ref(ref => ref.id(headRefID));
        })
        .build();
    });
  }

  beforeEach(async function() {
    repositoryID = 'repository0';
    headRefID = 'headref0';

    expectRepositoryQuery().resolve();
    expectIssueishSearchQuery().resolve();
    expectIssueishDetailQuery().resolve();
    expectMentionableUsersQuery().resolve();
    expectCurrentPullRequestQuery().resolve();
    expectCommentDecorationsQuery().resolve();

    context = await setup({
      initialRoots: ['three-files'],
    });
    wrapper = context.wrapper;
    atomEnv = context.atomEnv;
    workspaceElement = context.workspaceElement;

    await context.loginModel.setToken('https://api.github.com', 'good-token');

    const root = atomEnv.project.getPaths()[0];
    git = new GitShellOutStrategy(root);
    await git.exec(['remote', 'add', 'dotcom', 'https://github.com/owner/repo.git']);

    const mockGitServer = hock.createHock();

    const uploadPackAdvertisement = '001e# service=git-upload-pack\n' +
      '0000' +
      '005b66d11860af6d28eb38349ef83de475597cb0e8b4 HEAD\0multi_ack symref=HEAD:refs/heads/pr-head\n' +
      '004066d11860af6d28eb38349ef83de475597cb0e8b4 refs/heads/pr-head\n' +
      '0000';

    mockGitServer
      .get('/owner/repo.git/info/refs?service=git-upload-pack')
      .reply(200, uploadPackAdvertisement, {'Content-Type': 'application/x-git-upload-pack-advertisement'})
      .get('/owner/repo.git/info/refs?service=git-upload-pack')
      .reply(400);

    const server = http.createServer(mockGitServer.handler);
    return new Promise(resolve => {
      server.listen(0, '127.0.0.1', async () => {
        const {address, port} = server.address();
        await git.setConfig(`url.http://${address}:${port}/.insteadOf`, 'https://github.com/');

        resolve();
      });
    });
  });

  afterEach(async function() {
    await teardown(context);
  });

  it('opens a pane item for a pull request by clicking on an entry in the GitHub tab', async function() {
    // Open the GitHub tab and wait for results to be rendered
    await atomEnv.commands.dispatch(workspaceElement, 'github:toggle-github-tab');
    await assert.async.isTrue(wrapper.update().find('.github-IssueishList-item').exists());

    // Click on PR #1
    const prOne = wrapper.find('.github-Accordion-listItem').filterWhere(li => {
      return li.find('.github-IssueishList-item--number').text() === '#1';
    });
    prOne.simulate('click');

    // Wait for the pane item to open and fetch
    await assert.async.include(
      atomEnv.workspace.getActivePaneItem().getTitle(),
      'PR: owner/repo#1 — Pull Request 1',
    );
    assert.strictEqual(wrapper.update().find('.github-IssueishDetailView-title').text(), 'Pull Request 1');

    // Click on the "Checkout" button
    await wrapper.find('.github-IssueishDetailView-checkoutButton').prop('onClick')();

    // Ensure that the correct ref has been fetched and checked out
    const branches = await git.getBranches();
    const head = branches.find(b => b.head);
    assert.strictEqual(head.name, 'pr-1/owner/pr-head');

    await assert.async.isTrue(wrapper.update().find('.github-IssueishDetailView-checkoutButton--current').exists());
  });
});
