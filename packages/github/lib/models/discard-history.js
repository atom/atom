import path from 'path';
import os from 'os';
import fs from 'fs-extra';

import mkdirp from 'mkdirp';

import {PartialFileDiscardHistory, WholeFileDiscardHistory} from './discard-history-stores';

import {getTempDir, fileExists} from '../helpers';

const emptyFilePath = path.join(os.tmpdir(), 'empty-file.txt');
const emptyFilePromise = fs.writeFile(emptyFilePath, '');

export default class DiscardHistory {
  constructor(createBlob, expandBlobToFile, mergeFile, workdirPath, {maxHistoryLength} = {}) {
    this.createBlob = createBlob;
    this.expandBlobToFile = expandBlobToFile;
    this.mergeFile = mergeFile;
    this.workdirPath = workdirPath;
    this.partialFileHistory = new PartialFileDiscardHistory(maxHistoryLength);
    this.wholeFileHistory = new WholeFileDiscardHistory(maxHistoryLength);
  }

  getLastSnapshots(partialDiscardFilePath = null) {
    if (partialDiscardFilePath) {
      return this.partialFileHistory.getLastSnapshotsForPath(partialDiscardFilePath);
    } else {
      return this.wholeFileHistory.getLastSnapshots();
    }
  }

  getHistory(partialDiscardFilePath = null) {
    if (partialDiscardFilePath) {
      return this.partialFileHistory.getHistoryForPath(partialDiscardFilePath);
    } else {
      return this.wholeFileHistory.getHistory();
    }
  }

  hasHistory(partialDiscardFilePath = null) {
    const history = this.getHistory(partialDiscardFilePath);
    return history.length > 0;
  }

  popHistory(partialDiscardFilePath = null) {
    if (partialDiscardFilePath) {
      return this.partialFileHistory.popHistoryForPath(partialDiscardFilePath);
    } else {
      return this.wholeFileHistory.popHistory();
    }
  }

  clearHistory(partialDiscardFilePath = null) {
    if (partialDiscardFilePath) {
      this.partialFileHistory.clearHistoryForPath(partialDiscardFilePath);
    } else {
      this.wholeFileHistory.clearHistory();
    }
  }

  updateHistory(history) {
    this.partialFileHistory.setHistory(history.partialFileHistory || {});
    this.wholeFileHistory.setHistory(history.wholeFileHistory || []);
  }

  async createHistoryBlob() {
    const histories = {
      wholeFileHistory: this.wholeFileHistory.getHistory(),
      partialFileHistory: this.partialFileHistory.getHistory(),
    };
    const historySha = await this.createBlob({stdin: JSON.stringify(histories)});
    return historySha;
  }

  async storeBeforeAndAfterBlobs(filePaths, isSafe, destructiveAction, partialDiscardFilePath = null) {
    if (partialDiscardFilePath) {
      return await this.storeBlobsForPartialFileHistory(partialDiscardFilePath, isSafe, destructiveAction);
    } else {
      return await this.storeBlobsForWholeFileHistory(filePaths, isSafe, destructiveAction);
    }
  }

  async storeBlobsForPartialFileHistory(filePath, isSafe, destructiveAction) {
    const beforeSha = await this.createBlob({filePath});
    const isNotSafe = !(await isSafe());
    if (isNotSafe) { return null; }
    await destructiveAction();
    const afterSha = await this.createBlob({filePath});
    const snapshots = {beforeSha, afterSha};
    this.partialFileHistory.addHistory(filePath, snapshots);
    return snapshots;
  }

  async storeBlobsForWholeFileHistory(filePaths, isSafe, destructiveAction) {
    const snapshotsByPath = {};
    const beforePromises = filePaths.map(async filePath => {
      snapshotsByPath[filePath] = {beforeSha: await this.createBlob({filePath})};
    });
    await Promise.all(beforePromises);
    const isNotSafe = !(await isSafe());
    if (isNotSafe) { return null; }
    await destructiveAction();
    const afterPromises = filePaths.map(async filePath => {
      snapshotsByPath[filePath].afterSha = await this.createBlob({filePath});
    });
    await Promise.all(afterPromises);
    this.wholeFileHistory.addHistory(snapshotsByPath);
    return snapshotsByPath;
  }

  async restoreLastDiscardInTempFiles(isSafe, partialDiscardFilePath = null) {
    let lastDiscardSnapshots = this.getLastSnapshots(partialDiscardFilePath);
    if (partialDiscardFilePath) {
      lastDiscardSnapshots = lastDiscardSnapshots ? [lastDiscardSnapshots] : [];
    }
    const tempFolderPaths = await this.expandBlobsToFilesInTempFolder(lastDiscardSnapshots);
    if (!isSafe()) { return []; }
    return await this.mergeFiles(tempFolderPaths);
  }

  async expandBlobsToFilesInTempFolder(snapshots) {
    const tempFolderPath = await getTempDir({prefix: 'github-discard-history-'});
    const pathPromises = snapshots.map(async ({filePath, beforeSha, afterSha}) => {
      const dir = path.dirname(path.join(tempFolderPath, filePath));
      await mkdirp(dir);
      const theirsPath = !beforeSha ? null :
        await this.expandBlobToFile(path.join(tempFolderPath, `${filePath}-before-discard`), beforeSha);
      const commonBasePath = !afterSha ? null :
        await this.expandBlobToFile(path.join(tempFolderPath, `${filePath}-after-discard`), afterSha);
      const resultPath = path.join(tempFolderPath, `~${path.basename(filePath)}-merge-result`);
      return {filePath, commonBasePath, theirsPath, resultPath, theirsSha: beforeSha, commonBaseSha: afterSha};
    });
    return await Promise.all(pathPromises);
  }

  async mergeFiles(filePaths) {
    const mergeFilePromises = filePaths.map(async (filePathInfo, i) => {
      const {filePath, commonBasePath, theirsPath, resultPath, theirsSha, commonBaseSha} = filePathInfo;
      const currentSha = await this.createBlob({filePath});
      let mergeResult;
      if (theirsPath && commonBasePath) {
        mergeResult = await this.mergeFile(filePath, commonBasePath, theirsPath, resultPath);
      } else if (!theirsPath && commonBasePath) { // deleted file
        const oursSha = await this.createBlob({filePath});
        if (oursSha === commonBaseSha) { // no changes since discard, mark file to be deleted
          mergeResult = {filePath, resultPath: null, deleted: true, conflict: false};
        } else { // changes since discard result in conflict
          await fs.copy(path.join(this.workdirPath, filePath), resultPath);
          mergeResult = {filePath, resultPath, conflict: true};
        }
      } else if (theirsPath && !commonBasePath) { // added file
        const fileDoesExist = await fileExists(path.join(this.workdirPath, filePath));
        if (!fileDoesExist) {
          await fs.copy(theirsPath, resultPath);
          mergeResult = {filePath, resultPath, conflict: false};
        } else {
          await emptyFilePromise;
          mergeResult = await this.mergeFile(filePath, emptyFilePath, theirsPath, resultPath);
        }
      } else {
        throw new Error('One of the following must be defined - theirsPath:' +
          `${theirsPath} or commonBasePath: ${commonBasePath}`);
      }
      return {...mergeResult, theirsSha, commonBaseSha, currentSha};
    });
    return await Promise.all(mergeFilePromises);
  }
}
