import React from 'react';
import {shallow} from 'enzyme';

import GithubTabHeaderController from '../../lib/controllers/github-tab-header-controller';
import {nullAuthor} from '../../lib/models/author';
import {Disposable} from 'atom';

describe('GithubTabHeaderController', function() {
  function *createWorkdirs(workdirs) {
    for (const workdir of workdirs) {
      yield workdir;
    }
  }

  function buildApp(overrides) {
    const props = {
      user: nullAuthor,
      currentWorkDir: null,
      contextLocked: false,
      changeWorkingDirectory: () => {},
      setContextLock: () => {},
      getCurrentWorkDirs: () => createWorkdirs([]),
      onDidChangeWorkDirs: () => new Disposable(),
      ...overrides,
    };
    return (
      <GithubTabHeaderController
        {...props}
      />
    );
  }

  it('get currentWorkDirs initializes workdirs state', function() {
    const paths = ['should be equal'];
    const wrapper = shallow(buildApp({getCurrentWorkDirs: () => createWorkdirs(paths)}));
    assert.strictEqual(wrapper.state(['currentWorkDirs']).next().value, paths[0]);
  });

  it('calls onDidChangeWorkDirs after mount', function() {
    const onDidChangeWorkDirs = sinon.spy();
    shallow(buildApp({onDidChangeWorkDirs}));
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('does not call onDidChangeWorkDirs on update', function() {
    const onDidChangeWorkDirs = sinon.spy();
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('calls onDidChangeWorkDirs on update to setup new listener', function() {
    let onDidChangeWorkDirs = () => null;
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    onDidChangeWorkDirs = sinon.spy();
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('calls onDidChangeWorkDirs on update and disposes old listener', function() {
    const disposeSpy = sinon.spy();
    let onDidChangeWorkDirs = () => ({dispose: disposeSpy});
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    onDidChangeWorkDirs = sinon.spy();
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
    assert.isTrue(disposeSpy.calledOnce);
  });

  it('updates workdirs', function() {
    let getCurrentWorkDirs = () => createWorkdirs([]);
    getCurrentWorkDirs = sinon.spy(getCurrentWorkDirs);
    const wrapper = shallow(buildApp({getCurrentWorkDirs}));
    wrapper.instance().resetWorkDirs();
    assert.isTrue(getCurrentWorkDirs.calledTwice);
  });

  it('handles a lock toggle', async function() {
    let resolveLockChange;
    const setContextLock = sinon.stub().returns(new Promise(resolve => {
      resolveLockChange = resolve;
    }));
    const wrapper = shallow(buildApp({currentWorkDir: 'the/workdir', contextLocked: false, setContextLock}));

    assert.isFalse(wrapper.find('GithubTabHeaderView').prop('contextLocked'));
    assert.isFalse(wrapper.find('GithubTabHeaderView').prop('changingLock'));

    const handlerPromise = wrapper.find('GithubTabHeaderView').prop('handleLockToggle')();
    wrapper.update();

    assert.isTrue(wrapper.find('GithubTabHeaderView').prop('contextLocked'));
    assert.isTrue(wrapper.find('GithubTabHeaderView').prop('changingLock'));
    assert.isTrue(setContextLock.calledWith('the/workdir', true));

    // Ignored while in-progress
    wrapper.find('GithubTabHeaderView').prop('handleLockToggle')();

    resolveLockChange();
    await handlerPromise;

    assert.isFalse(wrapper.find('GithubTabHeaderView').prop('changingLock'));
  });

  it('handles a workdir selection', async function() {
    let resolveWorkdirChange;
    const changeWorkingDirectory = sinon.stub().returns(new Promise(resolve => {
      resolveWorkdirChange = resolve;
    }));
    const wrapper = shallow(buildApp({currentWorkDir: 'original', changeWorkingDirectory}));

    assert.strictEqual(wrapper.find('GithubTabHeaderView').prop('workdir'), 'original');
    assert.isFalse(wrapper.find('GithubTabHeaderView').prop('changingWorkDir'));

    const handlerPromise = wrapper.find('GithubTabHeaderView').prop('handleWorkDirChange')({
      target: {value: 'work/dir'},
    });
    wrapper.update();

    assert.strictEqual(wrapper.find('GithubTabHeaderView').prop('workdir'), 'work/dir');
    assert.isTrue(wrapper.find('GithubTabHeaderView').prop('changingWorkDir'));
    assert.isTrue(changeWorkingDirectory.calledWith('work/dir'));

    // Ignored while in-progress
    wrapper.find('GithubTabHeaderView').prop('handleWorkDirChange')({
      target: {value: 'ig/nored'},
    });

    resolveWorkdirChange();
    await handlerPromise;

    assert.isFalse(wrapper.find('GithubTabHeaderView').prop('changingWorkDir'));
  });

  it('disposes on unmount', function() {
    const disposeSpy = sinon.spy();
    const onDidChangeWorkDirs = () => ({dispose: disposeSpy});
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    wrapper.unmount();
    assert.isTrue(disposeSpy.calledOnce);
  });

  it('unmounts without error', function() {
    const wrapper = shallow(buildApp());
    wrapper.unmount();
    assert.strictEqual(wrapper.children().length, 0);
  });
});
