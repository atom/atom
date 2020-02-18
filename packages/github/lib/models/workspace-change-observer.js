import path from 'path';
import {CompositeDisposable, Disposable, Emitter} from 'event-kit';
import {watchPath} from 'atom';

import EventLogger from './event-logger';
import {autobind} from '../helpers';

export const FOCUS = Symbol('focus');

export default class WorkspaceChangeObserver {
  constructor(window, workspace, repository) {
    autobind(this, 'observeTextEditor');

    this.window = window;
    this.repository = repository;
    this.workspace = workspace;
    this.observedBuffers = new WeakSet();
    this.emitter = new Emitter();
    this.disposables = new CompositeDisposable();
    this.logger = new EventLogger('workspace watcher');
    this.started = false;
  }

  async start() {
    const focusHandler = event => {
      if (this.repository) {
        this.logger.showFocusEvent();
        this.didChange([{special: FOCUS}]);
      }
    };
    this.window.addEventListener('focus', focusHandler);
    this.disposables.add(
      this.workspace.observeTextEditors(this.observeTextEditor),
      new Disposable(() => this.window.removeEventListener('focus', focusHandler)),
    );
    await this.watchActiveRepositoryGitDirectory();
    this.started = true;
    return this;
  }

  async destroy() {
    this.started = false;
    this.observedBuffers = new WeakSet();
    this.emitter.dispose();
    this.disposables.dispose();
    await this.stopCurrentFileWatcher();
  }

  isStarted() {
    return this.started;
  }

  didChange(payload) {
    this.emitter.emit('did-change', payload);
  }

  didChangeWorkdirOrHead() {
    this.emitter.emit('did-change-workdir-or-head');
  }

  onDidChange(callback) {
    return this.emitter.on('did-change', callback);
  }

  onDidChangeWorkdirOrHead(callback) {
    return this.emitter.on('did-change-workdir-or-head', callback);
  }

  getRepository() {
    return this.repository;
  }

  async watchActiveRepositoryGitDirectory() {
    const repository = this.getRepository();
    const gitDirectoryPath = repository.getGitDirectoryPath();

    const basenamesOfInterest = ['config', 'index', 'HEAD', 'MERGE_HEAD'];
    const workdirOrHeadBasenames = ['config', 'index'];

    const eventPaths = event => {
      const ps = [event.path];
      if (event.oldPath) { ps.push(event.oldPath); }
      return ps;
    };

    const acceptEvent = event => {
      return eventPaths(event).some(eventPath => {
        return basenamesOfInterest.includes(path.basename(eventPath)) ||
          path.dirname(eventPath).includes(path.join('.git', 'refs'));
      });
    };

    const isWorkdirOrHeadEvent = event => {
      return eventPaths(event).some(eventPath => workdirOrHeadBasenames.includes(path.basename(eventPath)));
    };

    this.currentFileWatcher = await watchPath(gitDirectoryPath, {}, events => {
      const filteredEvents = events.filter(acceptEvent);

      if (filteredEvents.length) {
        this.logger.showEvents(filteredEvents);
        this.didChange(filteredEvents);
        if (filteredEvents.some(isWorkdirOrHeadEvent)) {
          this.logger.showWorkdirOrHeadEvents();
          this.didChangeWorkdirOrHead();
        }
      }
    });

    this.currentFileWatcher.onDidError(error => {
      const workingDirectory = repository.getWorkingDirectoryPath();
      // eslint-disable-next-line no-console
      console.warn(`Error in WorkspaceChangeObserver in ${workingDirectory}:`, error);
      this.stopCurrentFileWatcher();
    });

    this.logger.showStarted(gitDirectoryPath, 'workspace emulated');
  }

  stopCurrentFileWatcher() {
    if (this.currentFileWatcher) {
      this.currentFileWatcher.dispose();
      this.currentFileWatcher = null;
      this.logger.showStopped();
    }
    return Promise.resolve();
  }

  activeRepositoryContainsPath(filePath) {
    const repository = this.getRepository();
    if (filePath && repository) {
      return filePath.indexOf(repository.getWorkingDirectoryPath()) !== -1;
    } else {
      return false;
    }
  }

  observeTextEditor(editor) {
    const buffer = editor.getBuffer();
    if (!this.observedBuffers.has(buffer)) {
      let lastPath = buffer.getPath();
      const didChange = () => {
        const currentPath = buffer.getPath();
        const events = currentPath === lastPath ?
          [{action: 'modified', path: currentPath}] :
          [{action: 'renamed', path: currentPath, oldPath: lastPath}];
        lastPath = currentPath;
        this.logger.showEvents(events);
        this.didChange(events);
      };

      this.observedBuffers.add(buffer);
      const disposables = new CompositeDisposable(
        buffer.onDidSave(() => {
          if (this.activeRepositoryContainsPath(buffer.getPath())) {
            didChange();
          }
        }),
        buffer.onDidReload(() => {
          if (this.activeRepositoryContainsPath(buffer.getPath())) {
            didChange();
          }
        }),
        buffer.onDidDestroy(() => {
          if (this.activeRepositoryContainsPath(buffer.getPath())) {
            didChange();
          }
          disposables.dispose();
        }),
      );
      this.disposables.add(disposables);
    }
  }
}
