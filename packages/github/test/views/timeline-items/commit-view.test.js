/* eslint-disable jsx-a11y/alt-text */
import React from 'react';
import {shallow} from 'enzyme';

import {BareCommitView} from '../../../lib/views/timeline-items/commit-view';

describe('CommitView', function() {
  function buildApp(opts, overrideProps = {}) {
    const commit = {
      author: {
        name: 'author_name',
        avatarUrl: 'URL1',
        user: {
          login: 'author_login',
        },
      },
      committer: {
        name: 'committer_name',
        avatarUrl: 'URL2',
        user: {
          login: 'committer_login',
        },
      },
      sha: 'e6c80aa37dc6f7a5e5491e0ed6e00ec2c812b1a5',
      message: 'commit message',
      messageHeadlineHTML: '<h1>html</h1>',
      commitURL: 'https://github.com/aaa/bbb/commit/123abc',
      ...opts,
    };
    const props = {
      commit,
      onBranch: false,
      openCommit: () => {},
      ...overrideProps,
    };
    return <BareCommitView {...props} />;
  }
  it('prefers displaying usernames from `user.login`', function() {
    const app = buildApp();
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img title="author_login" />),
    );
    assert.isTrue(
      instance.containsMatchingElement(<img title="committer_login" />),
    );
  });

  it('displays the names if the are no usernames ', function() {
    const author = {
      name: 'author_name',
      avatarUrl: '',
      user: null,
    };
    const committer = {
      name: 'committer_name',
      avatarUrl: '',
      user: null,
    };
    const app = buildApp({author, committer});
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img title="author_name" />),
    );
    assert.isTrue(
      instance.containsMatchingElement(<img title="committer_name" />),
    );
  });

  it('ignores committer when it authored by the same person', function() {
    const author = {
      name: 'author_name',
      avatarUrl: '',
      user: {
        login: 'author_login',
      },
    };
    const committer = {
      name: 'author_name',
      avatarUrl: '',
      user: null,
    };
    const app = buildApp({author, committer});
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img title="author_login" />),
    );
    assert.isFalse(
      instance.containsMatchingElement(<img title="committer_name" />),
    );
  });

  it('ignores the committer when it is authored by GitHub', function() {
    const committer = {
      name: 'GitHub', avatarUrl: '',
      user: null,
    };
    const app = buildApp({committer});
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img title="author_login" />),
    );
    assert.isFalse(
      instance.containsMatchingElement(<img title="GitHub" />),
    );
  });

  it('ignores the committer when it uses the GitHub no-reply address', function() {
    const committer = {
      name: 'Someone', email: 'noreply@github.com', avatarUrl: '',
      user: null,
    };
    const app = buildApp({committer});
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img title="author_login" />),
    );
    assert.isFalse(
      instance.containsMatchingElement(<img title="GitHub" />),
    );
  });

  it('renders avatar URLs', function() {
    const app = buildApp();
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<img src="URL1" />),
    );
    assert.isTrue(
      instance.containsMatchingElement(<img src="URL2" />),
    );
  });

  it('shows the full commit message as tooltip', function() {
    const app = buildApp({message: 'full message'});
    const instance = shallow(app);
    assert.isTrue(
      instance.containsMatchingElement(<span title="full message" />),
    );
  });

  it('renders commit message headline', function() {
    const commit = {
      author: {
        name: 'author_name', avatarUrl: '',
        user: {
          login: 'author_login',
        },
      },
      committer: {
        name: 'author_name', avatarUrl: '',
        user: null,
      },
      sha: 'e6c80aa37dc6f7a5e5491e0ed6e00ec2c812b1a5',
      authoredByCommitter: true,
      message: 'full message',
      messageHeadlineHTML: '<h1>inner HTML</h1>',
      commitURL: 'https://github.com/aaa/bbb/commit/123abc',
    };
    const app = <BareCommitView commit={commit} openCommit={() => {}} onBranch={false} />;
    const instance = shallow(app);
    assert.match(instance.html(), /<h1>inner HTML<\/h1>/);
  });

  it('renders commit sha', function() {
    const commit = {
      author: {
        name: 'author_name', avatarUrl: '',
        user: {
          login: 'author_login',
        },
      },
      committer: {
        name: 'author_name', avatarUrl: '',
        user: null,
      },
      sha: 'e6c80aa37dc6f7a5e5491e0ed6e00ec2c812b1a5',
      authoredByCommitter: true,
      message: 'full message',
      messageHeadlineHTML: '<h1>inner HTML</h1>',
      commitURL: 'https://github.com/aaa/bbb/commit/123abc',
    };
    const app = <BareCommitView commit={commit} onBranch={false} openCommit={() => {}} />;
    const instance = shallow(app);
    assert.match(instance.text(), /e6c80aa3/);
  });

  it('opens a CommitDetailcommit on click when the commit is on a branch', function() {
    const openCommit = sinon.spy();
    const sha = 'e6c80aa37dc6f7a5e5491e0ed6e00ec2c812b1a5';
    const app = buildApp({sha}, {openCommit, onBranch: true});
    const wrapper = shallow(app);

    assert.isTrue(wrapper.find('.commit-message-headline button').exists());

    wrapper.find('.commit-message-headline button').simulate('click');
    assert.isTrue(openCommit.calledWith({sha}));
  });

  it('renders the message headline as a span when the commit is not on a branch', function() {
    const openCommit = sinon.spy();
    const app = buildApp({}, {openCommit, onBranch: false});
    const wrapper = shallow(app);

    assert.isTrue(wrapper.find('.commit-message-headline span').exists());
    assert.isFalse(wrapper.find('.commit-message-headline button').exists());
  });
});
