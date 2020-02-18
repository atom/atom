import React from 'react';
import {shallow, mount} from 'enzyme';
import moment from 'moment';
import dedent from 'dedent-js';

import CommitDetailView from '../../lib/views/commit-detail-view';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import Commit from '../../lib/models/commit';
import Remote, {nullRemote} from '../../lib/models/remote';
import {cloneRepository, buildRepository} from '../helpers';
import {commitBuilder} from '../builder/commit';

describe('CommitDetailView', function() {
  let repository, atomEnv;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository('multiple-commits'));
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      repository,
      commit: commitBuilder().setMultiFileDiff().build(),
      currentRemote: new Remote('origin', 'git@github.com:atom/github'),
      messageCollapsible: false,
      messageOpen: true,
      isCommitPushed: true,
      itemType: CommitDetailItem,

      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,

      destroy: () => { },
      toggleMessage: () => { },
      surfaceCommit: () => { },
      ...override,
    };

    return <CommitDetailView {...props} />;
  }

  it('has a MultiFilePatchController that its itemType set', function() {
    const wrapper = shallow(buildApp({itemType: CommitDetailItem}));
    assert.strictEqual(wrapper.find('MultiFilePatchController').prop('itemType'), CommitDetailItem);
  });

  it('passes unrecognized props to a MultiFilePatchController', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));
    assert.strictEqual(wrapper.find('MultiFilePatchController').prop('extra'), extra);
  });

  it('renders commit details properly', function() {
    const commit = commitBuilder()
      .sha('420')
      .addAuthor('very@nice.com', 'Forthe Win')
      .authorDate(moment().subtract(2, 'days').unix())
      .messageSubject('subject')
      .messageBody('body')
      .setMultiFileDiff()
      .build();
    const wrapper = shallow(buildApp({commit}));

    assert.strictEqual(wrapper.find('.github-CommitDetailView-title').text(), 'subject');
    assert.strictEqual(wrapper.find('.github-CommitDetailView-moreText').text(), 'body');
    assert.strictEqual(wrapper.find('.github-CommitDetailView-metaText').text(), 'Forthe Win committed 2 days ago');
    assert.strictEqual(wrapper.find('.github-CommitDetailView-sha').text(), '420');
    assert.strictEqual(wrapper.find('.github-CommitDetailView-sha a').prop('href'), 'https://github.com/atom/github/commit/420');
    assert.strictEqual(
      wrapper.find('img.github-RecentCommit-avatar').prop('src'),
      'https://avatars.githubusercontent.com/u/e?email=very%40nice.com&s=32',
    );
  });

  it('renders multiple avatars for co-authored commit', function() {
    const commit = commitBuilder()
      .addAuthor('blaze@it.com', 'blaze')
      .addCoAuthor('two@coauthor.com', 'two')
      .addCoAuthor('three@coauthor.com', 'three')
      .build();
    const wrapper = shallow(buildApp({commit}));
    assert.deepEqual(
      wrapper.find('img.github-RecentCommit-avatar').map(w => w.prop('src')),
      [
        'https://avatars.githubusercontent.com/u/e?email=blaze%40it.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=two%40coauthor.com&s=32',
        'https://avatars.githubusercontent.com/u/e?email=three%40coauthor.com&s=32',
      ],
    );
  });

  it('handles noreply email addresses', function() {
    const commit = commitBuilder()
      .addAuthor('1234+username@users.noreply.github.com', 'noreply')
      .build();
    const wrapper = shallow(buildApp({commit}));

    assert.strictEqual(
      wrapper.find('img.github-CommitDetailView-avatar').prop('src'),
      'https://avatars.githubusercontent.com/u/1234?s=32',
    );
  });

  describe('dotcom link rendering', function() {
    it('renders a link to GitHub', function() {
      const wrapper = shallow(buildApp({
        commit: commitBuilder().sha('0123').build(),
        currentRemote: new Remote('dotcom', 'git@github.com:atom/github'),
        isCommitPushed: true,
      }));

      const link = wrapper.find('a');
      assert.strictEqual(link.text(), '0123');
      assert.strictEqual(link.prop('href'), 'https://github.com/atom/github/commit/0123');
    });

    it('omits the link if there is no current remote', function() {
      const wrapper = shallow(buildApp({
        commit: commitBuilder().sha('0123').build(),
        currentRemote: nullRemote,
        isCommitPushed: true,
      }));

      assert.isFalse(wrapper.find('a').exists());
      assert.include(wrapper.find('span').map(w => w.text()), '0123');
    });

    it('omits the link if the current remote is not a GitHub remote', function() {
      const wrapper = shallow(buildApp({
        commit: commitBuilder().sha('0123').build(),
        currentRemote: new Remote('elsewhere', 'git@somehost.com:atom/github'),
        isCommitPushed: true,
      }));

      assert.isFalse(wrapper.find('a').exists());
      assert.include(wrapper.find('span').map(w => w.text()), '0123');
    });

    it('omits the link if the commit is not pushed', function() {
      const wrapper = shallow(buildApp({
        commit: commitBuilder().sha('0123').build(),
        currentRemote: new Remote('dotcom', 'git@github.com:atom/github'),
        isCommitPushed: false,
      }));

      assert.isFalse(wrapper.find('a').exists());
      assert.include(wrapper.find('span').map(w => w.text()), '0123');
    });
  });

  describe('getAuthorInfo', function() {
    describe('when there are no co-authors', function() {
      it('returns only the author', function() {
        const commit = commitBuilder()
          .addAuthor('steven@universe.com', 'Steven Universe')
          .build();
        const wrapper = shallow(buildApp({commit}));
        assert.strictEqual(wrapper.instance().getAuthorInfo(), 'Steven Universe');
      });
    });

    describe('when there is one co-author', function() {
      it('returns author and the co-author', function() {
        const commit = commitBuilder()
          .addAuthor('ruby@universe.com', 'Ruby')
          .addCoAuthor('sapphire@thecrystalgems.party', 'Sapphire')
          .build();
        const wrapper = shallow(buildApp({commit}));
        assert.strictEqual(wrapper.instance().getAuthorInfo(), 'Ruby and Sapphire');
      });
    });

    describe('when there is more than one co-author', function() {
      it('returns the author and number of co-authors', function() {
        const commit = commitBuilder()
          .addAuthor('amethyst@universe.com', 'Amethyst')
          .addCoAuthor('peri@youclods.horse', 'Peridot')
          .addCoAuthor('p@pinkhair.club', 'Pearl')
          .build();
        const wrapper = shallow(buildApp({commit}));
        assert.strictEqual(wrapper.instance().getAuthorInfo(), 'Amethyst and 2 others');
      });
    });
  });

  describe('commit message collapsibility', function() {
    let wrapper, shortMessage, longMessage;

    beforeEach(function() {
      shortMessage = dedent`
        if every pork chop was perfect...

        we wouldn't have hot dogs!
        🌭🌭🌭🌭🌭🌭🌭
      `;

      longMessage = 'this message is really really really\n';
      while (longMessage.length < Commit.LONG_MESSAGE_THRESHOLD) {
        longMessage += 'really really really really really really\n';
      }
      longMessage += 'really really long.';
    });

    describe('when messageCollapsible is false', function() {
      beforeEach(function() {
        const commit = commitBuilder().messageBody(shortMessage).build();
        wrapper = shallow(buildApp({commit, messageCollapsible: false}));
      });

      it('renders the full message body', function() {
        assert.strictEqual(wrapper.find('.github-CommitDetailView-moreText').text(), shortMessage);
      });

      it('does not render a button', function() {
        assert.isFalse(wrapper.find('.github-CommitDetailView-moreButton').exists());
      });
    });

    describe('when messageCollapsible is true and messageOpen is false', function() {
      beforeEach(function() {
        const commit = commitBuilder().messageBody(longMessage).build();
        wrapper = shallow(buildApp({commit, messageCollapsible: true, messageOpen: false}));
      });

      it('renders an abbreviated commit message', function() {
        const messageText = wrapper.find('.github-CommitDetailView-moreText').text();
        assert.notStrictEqual(messageText, longMessage);
        assert.isAtMost(messageText.length, Commit.LONG_MESSAGE_THRESHOLD);
      });

      it('renders a button to reveal the rest of the message', function() {
        const button = wrapper.find('.github-CommitDetailView-moreButton');
        assert.lengthOf(button, 1);
        assert.strictEqual(button.text(), 'Show More');
      });
    });

    describe('when messageCollapsible is true and messageOpen is true', function() {
      let toggleMessage;

      beforeEach(function() {
        toggleMessage = sinon.spy();
        const commit = commitBuilder().messageBody(longMessage).build();
        wrapper = shallow(buildApp({commit, messageCollapsible: true, messageOpen: true, toggleMessage}));
      });

      it('renders the full message', function() {
        assert.strictEqual(wrapper.find('.github-CommitDetailView-moreText').text(), longMessage);
      });

      it('renders a button to collapse the message text', function() {
        const button = wrapper.find('.github-CommitDetailView-moreButton');
        assert.lengthOf(button, 1);
        assert.strictEqual(button.text(), 'Show Less');
      });

      it('the button calls toggleMessage when clicked', function() {
        const button = wrapper.find('.github-CommitDetailView-moreButton');
        button.simulate('click');
        assert.isTrue(toggleMessage.called);
      });
    });
  });

  describe('keyboard bindings', function() {
    it('surfaces the recent commit on github:surface', function() {
      const surfaceCommit = sinon.spy();
      const wrapper = mount(buildApp({surfaceCommit}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:surface');

      assert.isTrue(surfaceCommit.called);
    });

    it('surfaces from the embedded MultiFilePatchView', function() {
      const surfaceCommit = sinon.spy();
      const wrapper = mount(buildApp({surfaceCommit}));

      atomEnv.commands.dispatch(wrapper.find('.github-FilePatchView').getDOMNode(), 'github:surface');

      assert.isTrue(surfaceCommit.called);
    });
  });
});
