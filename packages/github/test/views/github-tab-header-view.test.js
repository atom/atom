import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';
import {nullAuthor} from '../../lib/models/author';

import GithubTabHeaderView from '../../lib/views/github-tab-header-view';

describe('GithubTabHeaderView', function() {
  function *createWorkdirs(workdirs) {
    for (const workdir of workdirs) {
      yield workdir;
    }
  }

  function build(options = {}) {
    const props = {
      user: nullAuthor,
      workdir: null,
      workdirs: createWorkdirs([]),
      contextLocked: false,
      changingWorkDir: false,
      changingLock: false,
      handleWorkDirChange: () => {},
      handleLockToggle: () => {},
      ...options,
    };
    return shallow(<GithubTabHeaderView {...props} />);
  }

  describe('with a select listener and paths', function() {
    let wrapper, select;
    const path1 = path.normalize('test/path/project1');
    const path2 = path.normalize('2nd-test/path/project2');
    const paths = [path1, path2];

    beforeEach(function() {
      select = sinon.spy();
      wrapper = build({handleWorkDirChange: select, workdirs: createWorkdirs(paths), workdir: path2});
    });

    it('renders an option for all given working directories', function() {
      wrapper.find('option').forEach(function(node, index) {
        assert.strictEqual(node.props().value, paths[index]);
        assert.strictEqual(node.children().text(), path.basename(paths[index]));
      });
    });

    it('selects the current working directory\'s path', function() {
      assert.strictEqual(wrapper.find('select').props().value, path2);
    });

    it('calls handleWorkDirSelect on select', function() {
      wrapper.find('select').simulate('change', {target: {value: path1}});
      assert.isTrue(select.calledWith({target: {value: path1}}));
    });
  });

  describe('context lock control', function() {
    it('renders locked when the lock is engaged', function() {
      const wrapper = build({contextLocked: true});

      assert.isTrue(wrapper.exists('Octicon[icon="lock"]'));
    });

    it('renders unlocked when the lock is disengaged', function() {
      const wrapper = build({contextLocked: false});

      assert.isTrue(wrapper.exists('Octicon[icon="unlock"]'));
    });

    it('calls handleLockToggle when the lock is clicked', function() {
      const handleLockToggle = sinon.spy();
      const wrapper = build({handleLockToggle});

      wrapper.find('button').simulate('click');
      assert.isTrue(handleLockToggle.called);
    });
  });

  describe('when changes are in progress', function() {
    it('disables the workdir select while the workdir is changing', function() {
      const wrapper = build({changingWorkDir: true});

      assert.isTrue(wrapper.find('select').prop('disabled'));
    });

    it('disables the context lock toggle while the context lock is changing', function() {
      const wrapper = build({changingLock: true});

      assert.isTrue(wrapper.find('button').prop('disabled'));
    });
  });

  describe('with falsish props', function() {
    let wrapper;

    beforeEach(function() {
      wrapper = build();
    });

    it('renders no options', function() {
      assert.isFalse(wrapper.find('select').children().exists());
    });

    it('renders an avatar placeholder', function() {
      assert.strictEqual(wrapper.find('img.github-Project-avatar').prop('src'), 'atom://github/img/avatar.svg');
    });
  });
});
