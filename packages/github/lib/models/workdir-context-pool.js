import compareSets from 'compare-sets';

import {Emitter} from 'event-kit';
import WorkdirContext from './workdir-context';

/**
 * Manage a WorkdirContext for each open directory.
 */
export default class WorkdirContextPool {

  /**
   * Options will be passed to each `WorkdirContext` as it is created.
   */
  constructor(options = {}) {
    this.options = options;

    this.contexts = new Map();
    this.emitter = new Emitter();
  }

  size() {
    return this.contexts.size;
  }

  /**
   * Access the context mapped to a known directory.
   */
  getContext(directory) {
    const {pipelineManager} = this.options;
    return this.contexts.get(directory) || WorkdirContext.absent({pipelineManager});
  }

  /**
   * Return a WorkdirContext whose Repository has at least one remote configured to push to the named GitHub repository.
   * Returns a null context if zero or more than one contexts match.
   */
  async getMatchingContext(host, owner, repo) {
    const matches = await Promise.all(
      this.withResidentContexts(async (_workdir, context) => {
        const match = await context.getRepository().hasGitHubRemote(host, owner, repo);
        return match ? context : null;
      }),
    );
    const filtered = matches.filter(Boolean);

    return filtered.length === 1 ? filtered[0] : WorkdirContext.absent({...this.options});
  }

  add(directory, options = {}, silenceEmitter = false) {
    if (this.contexts.has(directory)) {
      return this.getContext(directory);
    }

    const context = new WorkdirContext(directory, {...this.options, ...options});
    this.contexts.set(directory, context);

    const disposable = context.subs;

    const forwardEvent = (subMethod, emitEventName) => {
      const emit = () => this.emitter.emit(emitEventName, context);
      disposable.add(context[subMethod](emit));
    };

    forwardEvent('onDidStartObserver', 'did-start-observer');
    forwardEvent('onDidChangeWorkdirOrHead', 'did-change-workdir-or-head');
    forwardEvent('onDidChangeRepositoryState', 'did-change-repository-state');
    forwardEvent('onDidUpdateRepository', 'did-update-repository');
    forwardEvent('onDidDestroyRepository', 'did-destroy-repository');

    if (!silenceEmitter) {
      this.emitter.emit('did-change-contexts', {added: new Set([directory])});
    }

    return context;
  }

  replace(directory, options = {}, silenceEmitter = false) {
    this.remove(directory, true);
    this.add(directory, options, true);

    if (!silenceEmitter) {
      this.emitter.emit('did-change-contexts', {altered: new Set([directory])});
    }
  }

  remove(directory, silenceEmitter = false) {
    const existing = this.contexts.get(directory);
    this.contexts.delete(directory);

    if (existing) {
      existing.destroy();

      if (!silenceEmitter) {
        this.emitter.emit('did-change-contexts', {removed: new Set([directory])});
      }
    }
  }

  set(directories, options = {}) {
    const previous = new Set(this.contexts.keys());
    const {added, removed} = compareSets(previous, directories);

    for (const directory of added) {
      this.add(directory, options, true);
    }
    for (const directory of removed) {
      this.remove(directory, true);
    }

    if (added.size !== 0 || removed.size !== 0) {
      this.emitter.emit('did-change-contexts', {added, removed});
    }
  }

  getCurrentWorkDirs() {
    return this.contexts.keys();
  }

  withResidentContexts(callback) {
    const results = [];
    for (const [workdir, context] of this.contexts) {
      results.push(callback(workdir, context));
    }
    return results;
  }

  onDidStartObserver(callback) {
    return this.emitter.on('did-start-observer', callback);
  }

  onDidChangePoolContexts(callback) {
    return this.emitter.on('did-change-contexts', callback);
  }

  onDidChangeWorkdirOrHead(callback) {
    return this.emitter.on('did-change-workdir-or-head', callback);
  }

  onDidChangeRepositoryState(callback) {
    return this.emitter.on('did-change-repository-state', callback);
  }

  onDidUpdateRepository(callback) {
    return this.emitter.on('did-update-repository', callback);
  }

  onDidDestroyRepository(callback) {
    return this.emitter.on('did-destroy-repository', callback);
  }

  clear() {
    const workdirs = new Set();

    this.withResidentContexts(workdir => {
      this.remove(workdir, true);
      workdirs.add(workdir);
    });

    WorkdirContext.destroyAbsent();

    if (workdirs.size !== 0) {
      this.emitter.emit('did-change-contexts', {removed: workdirs});
    }
  }
}
