import path from 'path';

import {CompositeDisposable, Disposable} from 'event-kit';

import {cloneRepository} from '../helpers';

import WorkdirContext from '../../lib/models/workdir-context';

describe('WorkdirContext', function() {
  let context, workingDirectory, subs;
  let mockPromptCallback;

  beforeEach(async function() {
    workingDirectory = await cloneRepository('three-files');
    subs = new CompositeDisposable();

    const mockWindow = {
      addEventListener: sinon.spy(),
      removeEventListener: sinon.spy(),
    };

    const mockWorkspace = {
      observeTextEditors: sinon.stub().returns(new Disposable()),
    };

    mockPromptCallback = query => 'reply';

    context = new WorkdirContext(workingDirectory, {
      window: mockWindow,
      workspace: mockWorkspace,
      promptCallback: mockPromptCallback,
    });
  });

  afterEach(async function() {
    context && await context.destroy();
    subs.dispose();
  });

  it('returns synchronous models in their initial states', function() {
    assert.isTrue(context.getRepository().isLoading());
    assert.isTrue(context.getResolutionProgress().isEmpty());
    assert.isFalse(context.getChangeObserver().isStarted());
  });

  it('starts the change observer after the repository loads', async function() {
    const observer = context.getChangeObserver();
    await context.getObserverStartedPromise();
    assert.isTrue(observer.isStarted());
  });

  it('configures the repository with a prompt callback', async function() {
    const repo = context.getRepository();
    await repo.getLoadPromise();

    for (const strategy of repo.git.getImplementers()) {
      assert.strictEqual(strategy.prompt, mockPromptCallback);
    }
  });

  it('notifies the repository on any filesystem change', async function() {
    const repo = context.getRepository();
    await context.getRepositoryStatePromise('Present');

    sinon.spy(repo, 'observeFilesystemChange');

    const events = [{path: path.join('a', 'b', 'c')}];
    context.getChangeObserver().didChange(events);

    assert.isTrue(repo.observeFilesystemChange.calledWith(events));
  });

  it('re-emits an event on workdir or head change', async function() {
    const listener = sinon.spy();
    subs.add(context.onDidChangeWorkdirOrHead(listener));

    await context.getRepositoryStatePromise('Present');

    context.getChangeObserver().didChangeWorkdirOrHead();
    assert.isTrue(listener.called);
  });

  it('destroys the repository on destroy()', async function() {
    await context.getRepositoryStatePromise('Present');
    const repo = context.getRepository();

    await context.destroy();
    assert.isTrue(repo.isDestroyed());
  });

  it('stops the change observer on destroy()', async function() {
    await context.getObserverStartedPromise();

    await context.destroy();
    await assert.isFalse(context.getChangeObserver().isStarted());
  });

  it('can be destroyed twice', async function() {
    assert.isFalse(context.isDestroyed());

    await context.destroy();
    assert.isTrue(context.isDestroyed());

    await context.destroy();
    assert.isTrue(context.isDestroyed());
  });

  it('exports a singleton containing a Repository in the absent state', function() {
    assert.isTrue(WorkdirContext.absent().getRepository().isAbsent());
  });

  it('can be constructed containing an undetermined Repository that acts absent', function() {
    const undetermined = WorkdirContext.guess({});
    assert.isTrue(undetermined.getRepository().isUndetermined());
    assert.isFalse(undetermined.getRepository().showGitTabLoading());
    assert.isTrue(undetermined.getRepository().showGitTabInit());
  });

  it("can be constructed containing an undetermined Repository that acts like it's loading", function() {
    const undetermined = WorkdirContext.guess({projectPathCount: 1});
    assert.isTrue(undetermined.getRepository().isUndetermined());
    assert.isTrue(undetermined.getRepository().showGitTabLoading());
    assert.isFalse(undetermined.getRepository().showGitTabInit());
  });
});
