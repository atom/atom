import React from 'react';
import {shallow} from 'enzyme';

import GitTabHeaderController from '../../lib/controllers/git-tab-header-controller';
import Author, {nullAuthor} from '../../lib/models/author';
import {Disposable} from 'atom';

describe('GitTabHeaderController', function() {
  function *createWorkdirs(workdirs) {
    for (const workdir of workdirs) {
      yield workdir;
    }
  }

  function buildApp(overrides) {
    const props = {
      getCommitter: () => nullAuthor,
      currentWorkDir: null,
      getCurrentWorkDirs: () => createWorkdirs([]),
      changeWorkingDirectory: () => {},
      contextLocked: false,
      setContextLock: () => {},
      onDidChangeWorkDirs: () => new Disposable(),
      onDidUpdateRepo: () => new Disposable(),
      ...overrides,
    };
    return <GitTabHeaderController {...props} />;
  }

  it('get currentWorkDirs initializes workdirs state', function() {
    const paths = ['should be equal'];
    const wrapper = shallow(buildApp({getCurrentWorkDirs: () => createWorkdirs(paths)}));
    assert.strictEqual(wrapper.state(['currentWorkDirs']).next().value, paths[0]);
  });

  it('calls onDidChangeWorkDirs after mount', function() {
    const onDidChangeWorkDirs = sinon.spy(() => ({dispose: () => null}));
    shallow(buildApp({onDidChangeWorkDirs}));
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('calls onDidUpdateRepo after mount', function() {
    const onDidUpdateRepo = sinon.spy(() => ({dispose: () => null}));
    shallow(buildApp({onDidUpdateRepo}));
    assert.isTrue(onDidUpdateRepo.calledOnce);
  });

  it('does not call onDidChangeWorkDirs on update', function() {
    const onDidChangeWorkDirs = sinon.spy(() => ({dispose: () => null}));
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('calls onDidChangeWorkDirs on update to setup new listener', function() {
    let onDidChangeWorkDirs = sinon.spy(() => ({dispose: () => null}));
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    onDidChangeWorkDirs = sinon.spy(() => ({dispose: () => null}));
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
  });

  it('calls onDidUpdateRepo on update to setup new listener', function() {
    let onDidUpdateRepo = sinon.spy(() => ({dispose: () => null}));
    const wrapper = shallow(buildApp({onDidUpdateRepo, isRepoDestroyed: () => false}));
    onDidUpdateRepo = sinon.spy(() => ({dispose: () => null}));
    wrapper.setProps({onDidUpdateRepo});
    assert.isTrue(onDidUpdateRepo.calledOnce);
  });

  it('calls onDidChangeWorkDirs on update and disposes old listener', function() {
    const disposeSpy = sinon.spy();
    let onDidChangeWorkDirs = () => ({dispose: disposeSpy});
    const wrapper = shallow(buildApp({onDidChangeWorkDirs}));
    onDidChangeWorkDirs = sinon.spy(() => ({dispose: () => null}));
    wrapper.setProps({onDidChangeWorkDirs});
    assert.isTrue(onDidChangeWorkDirs.calledOnce);
    assert.isTrue(disposeSpy.calledOnce);
  });

  it('calls onDidUpdateRepo on update and disposes old listener', function() {
    const disposeSpy = sinon.spy();
    let onDidUpdateRepo = () => ({dispose: disposeSpy});
    const wrapper = shallow(buildApp({onDidUpdateRepo, isRepoDestroyed: () => false}));
    onDidUpdateRepo = sinon.spy(() => ({dispose: () => null}));
    wrapper.setProps({onDidUpdateRepo});
    assert.isTrue(onDidUpdateRepo.calledOnce);
    assert.isTrue(disposeSpy.calledOnce);
  });

  it('updates workdirs', function() {
    let getCurrentWorkDirs = () => createWorkdirs([]);
    getCurrentWorkDirs = sinon.spy(getCurrentWorkDirs);
    const wrapper = shallow(buildApp({getCurrentWorkDirs}));
    wrapper.instance().resetWorkDirs();
    assert.isTrue(getCurrentWorkDirs.calledTwice);
  });

  it('updates the committer if the method changes', async function() {
    const getCommitter = sinon.spy(() => new Author('upd@te.d', 'updated'));
    const wrapper = shallow(buildApp());
    wrapper.setProps({getCommitter});
    assert.isTrue(getCommitter.calledOnce);
    await assert.async.strictEqual(wrapper.state('committer').getEmail(), 'upd@te.d');
  });

  it('does not update the committer when not mounted', function() {
    const getCommitter = sinon.spy();
    const wrapper = shallow(buildApp({getCommitter}));
    wrapper.unmount();
    assert.isTrue(getCommitter.calledOnce);
  });

  it('handles a lock toggle', async function() {
    let resolveLockChange;
    const setContextLock = sinon.stub().returns(new Promise(resolve => {
      resolveLockChange = resolve;
    }));
    const wrapper = shallow(buildApp({currentWorkDir: 'the/workdir', contextLocked: false, setContextLock}));

    assert.isFalse(wrapper.find('GitTabHeaderView').prop('contextLocked'));
    assert.isFalse(wrapper.find('GitTabHeaderView').prop('changingLock'));

    const handlerPromise = wrapper.find('GitTabHeaderView').prop('handleLockToggle')();
    wrapper.update();

    assert.isTrue(wrapper.find('GitTabHeaderView').prop('contextLocked'));
    assert.isTrue(wrapper.find('GitTabHeaderView').prop('changingLock'));
    assert.isTrue(setContextLock.calledWith('the/workdir', true));

    // Ignored while in-progress
    wrapper.find('GitTabHeaderView').prop('handleLockToggle')();

    resolveLockChange();
    await handlerPromise;

    assert.isFalse(wrapper.find('GitTabHeaderView').prop('changingLock'));
  });

  it('handles a workdir selection', async function() {
    let resolveWorkdirChange;
    const changeWorkingDirectory = sinon.stub().returns(new Promise(resolve => {
      resolveWorkdirChange = resolve;
    }));
    const wrapper = shallow(buildApp({currentWorkDir: 'original', changeWorkingDirectory}));

    assert.strictEqual(wrapper.find('GitTabHeaderView').prop('workdir'), 'original');
    assert.isFalse(wrapper.find('GitTabHeaderView').prop('changingWorkDir'));

    const handlerPromise = wrapper.find('GitTabHeaderView').prop('handleWorkDirSelect')({
      target: {value: 'work/dir'},
    });
    wrapper.update();

    assert.strictEqual(wrapper.find('GitTabHeaderView').prop('workdir'), 'work/dir');
    assert.isTrue(wrapper.find('GitTabHeaderView').prop('changingWorkDir'));
    assert.isTrue(changeWorkingDirectory.calledWith('work/dir'));

    // Ignored while in-progress
    wrapper.find('GitTabHeaderView').prop('handleWorkDirSelect')({
      target: {value: 'ig/nored'},
    });

    resolveWorkdirChange();
    await handlerPromise;

    assert.isFalse(wrapper.find('GitTabHeaderView').prop('changingWorkDir'));
  });

  it('unmounts without error', function() {
    const wrapper = shallow(buildApp());
    wrapper.unmount();
    assert.strictEqual(wrapper.children().length, 0);
  });
});
