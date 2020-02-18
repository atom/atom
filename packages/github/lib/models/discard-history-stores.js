export class PartialFileDiscardHistory {
  constructor(maxHistoryLength) {
    this.blobHistoryByFilePath = {};
    this.maxHistoryLength = maxHistoryLength || 60;
  }

  getHistoryForPath(filePath) {
    const history = this.blobHistoryByFilePath[filePath];
    if (history) {
      return history;
    } else {
      this.setHistoryForPath(filePath, []);
      return this.blobHistoryByFilePath[filePath];
    }
  }

  setHistoryForPath(filePath, history) {
    this.blobHistoryByFilePath[filePath] = history;
  }

  getHistory() {
    return this.blobHistoryByFilePath;
  }

  setHistory(history) {
    this.blobHistoryByFilePath = history;
  }

  popHistoryForPath(filePath) {
    return this.getHistoryForPath(filePath).pop();
  }

  addHistory(filePath, snapshots) {
    const history = this.getHistoryForPath(filePath);
    history.push(snapshots);
    if (history.length >= this.maxHistoryLength) {
      this.setHistoryForPath(filePath, history.slice(Math.ceil(this.maxHistoryLength / 2)));
    }
  }

  getLastSnapshotsForPath(filePath) {
    const history = this.getHistoryForPath(filePath);
    const snapshots = history[history.length - 1];
    if (!snapshots) { return null; }
    return {filePath, ...snapshots};
  }

  clearHistoryForPath(filePath) {
    this.setHistoryForPath(filePath, []);
  }
}

export class WholeFileDiscardHistory {
  constructor(maxHistoryLength) {
    this.blobHistory = [];
    this.maxHistoryLength = maxHistoryLength || 60;
  }

  getHistory() {
    return this.blobHistory;
  }

  setHistory(history) {
    this.blobHistory = history;
  }

  popHistory() {
    return this.getHistory().pop();
  }

  addHistory(snapshotsByPath) {
    const history = this.getHistory();
    history.push(snapshotsByPath);
    if (history.length >= this.maxHistoryLength) {
      this.setHistory(history.slice(Math.ceil(this.maxHistoryLength / 2)));
    }
  }

  getLastSnapshots() {
    const history = this.getHistory();
    const snapshotsByPath = history[history.length - 1] || {};
    return Object.keys(snapshotsByPath).map(p => {
      return {filePath: p, ...snapshotsByPath[p]};
    });
  }

  clearHistory() {
    this.setHistory([]);
  }
}
