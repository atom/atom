import {CompositeDisposable} from 'event-kit';

import {setUpLocalAndRemoteRepositories} from '../helpers';
import Repository from '../../lib/models/repository';
import getRepoPipelineManager from '../../lib/get-repo-pipeline-manager';
import OperationStateObserver, {PUSH, FETCH} from '../../lib/models/operation-state-observer';

describe('OperationStateObserver', function() {
  let atomEnv, repository, observer, subs, handler;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    handler = sinon.stub();

    const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits');
    repository = new Repository(localRepoPath, null, {
      pipelineManager: getRepoPipelineManager({
        confirm: () => true,
        notificationManager: atomEnv.notifications,
        workspace: atomEnv.workspace,
      }),
    });
    await repository.getLoadPromise();

    subs = new CompositeDisposable();
  });

  afterEach(function() {
    observer && observer.dispose();
    subs.dispose();
    atomEnv.destroy();
  });

  it('triggers an update event when the observed repository completes an operation', async function() {
    observer = new OperationStateObserver(repository, PUSH);
    subs.add(observer.onDidComplete(handler));

    const operation = repository.push('master');
    assert.isFalse(handler.called);
    await operation;
    assert.isTrue(handler.called);
  });

  it('does not trigger an update event when the observed repository is unchanged', async function() {
    observer = new OperationStateObserver(repository, FETCH);
    subs.add(observer.onDidComplete(handler));

    await repository.push('master');
    assert.isFalse(handler.called);
  });

  it('subscribes to multiple events', async function() {
    observer = new OperationStateObserver(repository, FETCH, PUSH);
    subs.add(observer.onDidComplete(handler));

    await repository.push('master');
    assert.strictEqual(handler.callCount, 1);

    await repository.fetch('master');
    assert.strictEqual(handler.callCount, 2);

    await repository.pull('origin', 'master');
    assert.strictEqual(handler.callCount, 2);
  });
});
