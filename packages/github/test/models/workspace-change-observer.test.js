import path from 'path';
import fs from 'fs-extra';

import until from 'test-until';

import {cloneRepository, buildRepository} from '../helpers';

import WorkspaceChangeObserver from '../../lib/models/workspace-change-observer';

describe('WorkspaceChangeObserver', function() {
  let atomEnv, workspace, observer, changeSpy;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    atomEnv.config.set('core.fileSystemWatcher', 'native');
    workspace = atomEnv.workspace;
    changeSpy = sinon.spy();
  });

  function createObserver(repository) {
    observer = new WorkspaceChangeObserver(window, workspace, repository);
    observer.onDidChange(changeSpy);
    return observer;
  }

  afterEach(async function() {
    if (observer) {
      await observer.destroy();
    }
    atomEnv.destroy();
  });

  it('emits a change event when the window is focused', async function() {
    const workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);
    createObserver(repository);

    window.dispatchEvent(new FocusEvent('focus'));
    assert.isFalse(changeSpy.called);

    await observer.start();
    window.dispatchEvent(new FocusEvent('focus'));
    await until(() => changeSpy.calledOnce);
  });

  it('emits a change event when a staging action takes place', async function() {
    const workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);
    createObserver(repository);
    await observer.start();

    await fs.writeFile(path.join(workdirPath, 'a.txt'), 'change', {encoding: 'utf8'});
    await repository.stageFiles(['a.txt']);

    await assert.async.isTrue(changeSpy.called);
  });

  it('emits a change event when a buffer belonging to the project directory changes', async function() {
    const workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);
    const editor = await workspace.open(path.join(workdirPath, 'a.txt'));

    createObserver(repository);
    await observer.start();

    editor.setText('change');
    await editor.save();
    await until(() => changeSpy.calledOnce);

    changeSpy.resetHistory();
    editor.getBuffer().reload();
    await until(() => changeSpy.calledOnce);

    changeSpy.resetHistory();
    editor.destroy();
    await until(() => changeSpy.calledOnce);
  });

  describe('when a buffer is renamed', function() {
    it('emits a change event with the new path', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);
      const editor = await workspace.open(path.join(workdirPath, 'a.txt'));

      createObserver(repository);
      await observer.start();

      editor.getBuffer().setPath(path.join(workdirPath, 'renamed-path.txt'));

      editor.setText('change');
      await editor.save();
      await assert.async.isTrue(changeSpy.calledWith([{
        action: 'renamed',
        path: path.join(workdirPath, 'renamed-path.txt'),
        oldPath: path.join(workdirPath, 'a.txt'),
      }]));
    });
  });

  it('doesn\'t emit events for unsaved files', async function() {
    const workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);
    const editor = await workspace.open();

    createObserver(repository);
    await observer.start();

    assert.doesNotThrow(() => editor.destroy());
  });
});
