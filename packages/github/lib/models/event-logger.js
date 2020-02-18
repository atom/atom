import path from 'path';
import {remote} from 'electron';

let headless = null;

export default class EventLogger {
  constructor(kind) {
    this.kind = kind;
    this.directory = '<unknown>';
    this.shortDirectory = '<unknown>';

    if (headless === null) {
      headless = !remote.getCurrentWindow().isVisible();
    }
  }

  showStarted(directory, implementation) {
    this.directory = directory;
    this.shortDirectory = directory.split(path.sep).slice(-2).join(path.sep);

    if (!this.isEnabled()) {
      return;
    }

    this.shortLog(`${implementation} watcher started`);
  }

  showEvents(events) {
    if (!this.isEnabled()) {
      return;
    }

    const uniqueRelativeNames = new Set(events.map(event => {
      return path.relative(this.directory, event.path);
    }));

    const fileNames = Array.from(uniqueRelativeNames).slice(0, 3);
    const elipses = uniqueRelativeNames.size > 3 ? '...' : '';
    const summary = `${this.getShortName()}: ${fileNames.join(', ')}${elipses}`;

    /* eslint-disable no-console */
    if (headless) {
      const eventText = events.map(event => {
        if (event.action === 'renamed') {
          return `  ${event.oldPath} => ${event.path} (${event.action})\n`;
        } else {
          return `  ${event.path} (${event.action})\n`;
        }
      }).join('\n');
      console.log(summary + '\n' + eventText);
    } else {
      console.groupCollapsed(summary);
      console.table(events, ['action', 'path', 'oldPath']);
      console.groupEnd();
    }
    /* eslint-enable no-console */
  }

  showFocusEvent() {
    if (!this.isEnabled()) {
      return;
    }

    this.shortLog('focus triggered');
  }

  showWorkdirOrHeadEvents() {
    if (!this.isEnabled()) {
      return;
    }

    this.shortLog('working directory or HEAD change');
  }

  showStopped() {
    if (!this.isEnabled()) {
      return;
    }

    this.shortLog('stopped');
  }

  isEnabled() {
    return process.env.ATOM_GITHUB_FS_EVENT_LOG || atom.config.get('github.filesystemEventDiagnostics');
  }

  getShortName() {
    return `${this.kind} @ ${this.shortDirectory}`;
  }

  shortLog(line) {
    if (headless) {
      // eslint-disable-next-line no-console
      console.log(`${this.getShortName()}: ${line}`);
      return;
    }

    // eslint-disable-next-line no-console
    console.log('%c%s%c: %s',
      'font-weight: bold; color: blue;',
      this.getShortName(),
      'font-weight: normal; color: black;',
      line,
    );
  }
}
