import React from 'react';
import {shallow, mount} from 'enzyme';

import RecentCommitsView from '../../lib/views/recent-commits-view';
import CommitView from '../../lib/views/commit-view';
import {commitBuilder} from '../builder/commit';

describe('RecentCommitsView', function() {
  let atomEnv, app;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();

    app = (
      <RecentCommitsView
        commits={[]}
        clipboard={{}}
        isLoading={false}
        selectedCommitSha=""
        commands={atomEnv.commands}
        undoLastCommit={() => { }}
        openCommit={() => { }}
        selectNextCommit={() => { }}
        selectPreviousCommit={() => { }}
      />
    );
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('shows a placeholder while commits are empty and loading', function() {
    app = React.cloneElement(app, {commits: [], isLoading: true});
    const wrapper = shallow(app);

    assert.isFalse(wrapper.find('RecentCommitView').exists());
    assert.strictEqual(wrapper.find('.github-RecentCommits-message').text(), 'Recent commits');
  });

  it('shows a prompting message while commits are empty and not loading', function() {
    app = React.cloneElement(app, {commits: [], isLoading: false});
    const wrapper = shallow(app);

    assert.isFalse(wrapper.find('RecentCommitView').exists());
    assert.strictEqual(wrapper.find('.github-RecentCommits-message').text(), 'Make your first commit');
  });

  it('renders a RecentCommitView for each commit', function() {
    const commits = ['1', '2', '3'].map(sha => commitBuilder().sha(sha).build());

    app = React.cloneElement(app, {commits});
    const wrapper = shallow(app);

    assert.deepEqual(wrapper.find('RecentCommitView').map(w => w.prop('commit')), commits);
  });

  it('scrolls the selected RecentCommitView into visibility', function() {
    const commits = ['0', '1', '2', '3'].map(sha => commitBuilder().sha(sha).build());

    app = React.cloneElement(app, {commits, selectedCommitSha: '1'});
    const wrapper = mount(app);
    const scrollSpy = sinon.spy(wrapper.find('RecentCommitView').at(3).getDOMNode(), 'scrollIntoViewIfNeeded');

    wrapper.setProps({selectedCommitSha: '3'});

    assert.isTrue(scrollSpy.calledWith(false));
  });

  it('renders emojis in the commit subject', function() {
    const commits = [commitBuilder().messageSubject(':heart: :shirt: :smile:').build()];

    app = React.cloneElement(app, {commits});
    const wrapper = mount(app);
    assert.strictEqual(wrapper.find('.github-RecentCommit-message').text(), '❤️ 👕 😄');
  });

  it('renders an avatar corresponding to the GitHub user who authored the commit', function() {
    const commits = ['thr&ee@z.com', 'two@y.com', 'one@x.com'].map((authorEmail, i) => {
      return commitBuilder()
        .sha(`1111111111${i}`)
        .addAuthor(authorEmail, authorEmail)
        .build();
    });

    app = React.cloneElement(app, {commits});
    const wrapper = mount(app);
    assert.deepEqual(
      wrapper.find('img.github-RecentCommit-avatar').map(w => w.prop('src')),
      [
        'https://avatars.githubusercontent.com/u/e?email=thr%26ee%40z.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=two%40y.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=one%40x.com&s=32',
      ],
    );
  });

  it('renders multiple avatars for co-authored commits', function() {
    const commits = [
      commitBuilder()
        .addAuthor('thr&ee@z.com', 'thr&ee')
        .addCoAuthor('two@y.com', 'One')
        .addCoAuthor('one@x.com', 'Two')
        .build(),
    ];

    app = React.cloneElement(app, {commits});
    const wrapper = mount(app);
    assert.deepEqual(
      wrapper.find('img.github-RecentCommit-avatar').map(w => w.prop('src')),
      [
        'https://avatars.githubusercontent.com/u/e?email=thr%26ee%40z.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=two%40y.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=one%40x.com&s=32',
      ],
    );
  });

  it("renders the commit's relative age", function() {
    const commit = commitBuilder().authorDate(1519848555).build();

    app = React.cloneElement(app, {commits: [commit]});
    const wrapper = mount(app);
    assert.isTrue(wrapper.find('Timeago').prop('time').isSame(1519848555000));
  });

  it('renders emoji in the title attribute', function() {
    const commit = commitBuilder().messageSubject(':heart:').messageBody('and a commit body').build();

    app = React.cloneElement(app, {commits: [commit]});
    const wrapper = mount(app);

    assert.strictEqual(
      wrapper.find('.github-RecentCommit-message').prop('title'),
      '❤️\n\nand a commit body',
    );
  });

  it('renders the full commit message in a title attribute', function() {
    const commit = commitBuilder()
      .messageSubject('really really really really really really really long')
      .messageBody('and a commit body')
      .build();

    app = React.cloneElement(app, {commits: [commit]});
    const wrapper = mount(app);

    assert.strictEqual(
      wrapper.find('.github-RecentCommit-message').prop('title'),
      'really really really really really really really long\n\n' +
      'and a commit body',
    );
  });

  it('opens a commit on click, preserving keyboard focus', function() {
    const openCommit = sinon.spy();
    const commits = [
      commitBuilder().sha('0').build(),
      commitBuilder().sha('1').build(),
      commitBuilder().sha('2').build(),
    ];
    const wrapper = mount(React.cloneElement(app, {commits, openCommit, selectedCommitSha: '2'}));

    wrapper.find('RecentCommitView').at(1).simulate('click');

    assert.isTrue(openCommit.calledWith({sha: '1', preserveFocus: true}));
  });

  describe('keybindings', function() {
    it('advances to the next commit on core:move-down', function() {
      const selectNextCommit = sinon.spy();
      const wrapper = mount(React.cloneElement(app, {selectNextCommit}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'core:move-down');

      assert.isTrue(selectNextCommit.called);
    });

    it('retreats to the previous commit on core:move-up', function() {
      const selectPreviousCommit = sinon.spy();
      const wrapper = mount(React.cloneElement(app, {selectPreviousCommit}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'core:move-up');

      assert.isTrue(selectPreviousCommit.called);
    });

    it('opens the currently selected commit and does not preserve focus on github:dive', function() {
      const openCommit = sinon.spy();
      const wrapper = mount(React.cloneElement(app, {openCommit, selectedCommitSha: '1234'}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:dive');

      assert.isTrue(openCommit.calledWith({sha: '1234', preserveFocus: false}));
    });
  });

  describe('focus management', function() {
    let instance;

    beforeEach(function() {
      instance = mount(app).instance();
    });

    it('keeps focus when advancing', async function() {
      assert.strictEqual(
        await instance.advanceFocusFrom(RecentCommitsView.focus.RECENT_COMMIT),
        RecentCommitsView.focus.RECENT_COMMIT,
      );
    });

    it('retreats focus to the CommitView when retreating', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(RecentCommitsView.focus.RECENT_COMMIT),
        CommitView.lastFocus,
      );
    });

    it('returns null from unrecognized previous focuses', async function() {
      assert.isNull(await instance.advanceFocusFrom(CommitView.firstFocus));
      assert.isNull(await instance.retreatFocusFrom(CommitView.firstFocus));
    });
  });

  describe('copying details of a commit', function() {
    let wrapper;
    let clipboard;

    beforeEach(function() {
      const commits = [
        commitBuilder().sha('0000').messageSubject('subject 0').build(),
        commitBuilder().sha('1111').messageSubject('subject 1').build(),
        commitBuilder().sha('2222').messageSubject('subject 2').build(),
      ];
      clipboard = {write: sinon.spy()};
      app = React.cloneElement(app, {commits, clipboard});
      wrapper = mount(app);
    });

    it('copies the commit sha on github:copy-commit-sha', function() {
      const commitNode = wrapper.find('.github-RecentCommit').at(1).getDOMNode();
      atomEnv.commands.dispatch(commitNode, 'github:copy-commit-sha');
      assert.isTrue(clipboard.write.called);
      assert.isTrue(clipboard.write.calledWith('1111'));
    });

    it('copies the commit subject on github:copy-commit-subject', function() {
      const commitNode = wrapper.find('.github-RecentCommit').at(1).getDOMNode();
      atomEnv.commands.dispatch(commitNode, 'github:copy-commit-subject');
      assert.isTrue(clipboard.write.called);
      assert.isTrue(clipboard.write.calledWith('subject 1'));
    });
  });
});
