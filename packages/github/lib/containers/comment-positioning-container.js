import React from 'react';
import PropTypes from 'prop-types';
import crypto from 'crypto';
import {CompositeDisposable} from 'event-kit';
import yubikiri from 'yubikiri';
import {translateLinesGivenDiff, diffPositionToFilePosition} from 'whats-my-line';

import File from '../models/patch/file';
import ObserveModel from '../views/observe-model';
import {toNativePathSep} from '../helpers';

export default class CommentPositioningContainer extends React.Component {
  static propTypes = {
    localRepository: PropTypes.object.isRequired,
    multiFilePatch: PropTypes.object.isRequired,
    commentThreads: PropTypes.arrayOf(PropTypes.shape({
      comments: PropTypes.arrayOf(PropTypes.shape({
        position: PropTypes.number,
        path: PropTypes.string.isRequired,
      })).isRequired,
    })),
    prCommitSha: PropTypes.string.isRequired,
    children: PropTypes.func.isRequired,

    // For unit test injection
    translateLinesGivenDiff: PropTypes.func,
    diffPositionToFilePosition: PropTypes.func,
  }

  static defaultProps = {
    translateLinesGivenDiff,
    diffPositionToFilePosition,
    didTranslate: /* istanbul ignore next */ () => {},
  }

  constructor(props) {
    super(props);

    this.state = {translationsByFile: new Map()};
    this.subs = new CompositeDisposable();
  }

  static getDerivedStateFromProps(props, state) {
    const prevPaths = new Set(state.translationsByFile.keys());
    let changed = false;

    for (const thread of props.commentThreads) {
      const relPath = thread.comments[0].path;
      const commentPath = toNativePathSep(relPath);

      let existing = state.translationsByFile.get(commentPath);
      if (!existing) {
        existing = new FileTranslation(relPath);
        state.translationsByFile.set(commentPath, existing);
        changed = true;
      }
      existing.addCommentThread(thread);

      prevPaths.delete(commentPath);
    }

    for (const oldPath of prevPaths) {
      state.translationsByFile.deleted(oldPath);
      changed = true;
    }

    if (changed) {
      return {translationsByFile: state.translationsByFile};
    } else {
      return null;
    }
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  render() {
    const commentPaths = [...this.state.translationsByFile.keys()];

    return (
      <ObserveModel
        model={this.props.localRepository}
        fetchData={this.fetchData}
        fetchParams={[commentPaths, this.props.prCommitSha]}>

        {diffsByPath => {
          if (diffsByPath === null) {
            return this.props.children(null);
          }

          for (const commentPath of commentPaths) {
            this.state.translationsByFile.get(commentPath).updateIfNecessary({
              multiFilePatch: this.props.multiFilePatch,
              diffs: diffsByPath[commentPath] || [],
              diffPositionFn: this.props.diffPositionToFilePosition,
              translatePositionFn: this.props.translateLinesGivenDiff,
            });
          }

          return this.props.children(this.state.translationsByFile);
        }}

      </ObserveModel>
    );
  }

  fetchData = (localRepository, commentPaths, prCommitSha) => {
    const promises = {};
    for (const commentPath of commentPaths) {
      promises[commentPath] = localRepository.getDiffsForFilePath(commentPath, prCommitSha).catch(() => []);
    }
    return yubikiri(promises);
  }
}

class FileTranslation {
  constructor(relPath) {
    this.relPath = relPath;
    this.nativeRelPath = toNativePathSep(relPath);

    this.rawPositions = new Set();
    this.diffToFilePosition = new Map();
    this.removed = false;
    this.fileTranslations = null;
    this.digest = null;

    this.last = {multiFilePatch: null, diffs: null};
  }

  addCommentThread(thread) {
    this.rawPositions.add(thread.comments[0].position);
  }

  updateIfNecessary({multiFilePatch, diffs, diffPositionFn, translatePositionFn}) {
    if (
      this.last.multiFilePatch === multiFilePatch &&
      this.last.diffs === diffs
    ) {
      return false;
    }

    this.last.multiFilePatch = multiFilePatch;
    this.last.diffs = diffs;

    return this.update({multiFilePatch, diffs, diffPositionFn, translatePositionFn});
  }

  update({multiFilePatch, diffs, diffPositionFn, translatePositionFn}) {
    const filePatch = multiFilePatch.getPatchForPath(this.nativeRelPath);
    // Comment on a file that used to exist in a PR but no longer does. Skip silently.
    if (!filePatch) {
      this.diffToFilePosition = new Map();
      this.removed = false;
      this.fileTranslations = null;

      return;
    }

    // This comment was left on a file that was too large to parse.
    if (!filePatch.getRenderStatus().isVisible()) {
      this.diffToFilePosition = new Map();
      this.removed = true;
      this.fileTranslations = null;

      return;
    }

    this.diffToFilePosition = diffPositionFn(this.rawPositions, filePatch.getRawContentPatch());
    this.removed = false;

    let contentChangeDiff;
    if (diffs.length === 1) {
      contentChangeDiff = diffs[0];
    } else if (diffs.length === 2) {
      const [diff1, diff2] = diffs;
      if (diff1.oldMode === File.modes.SYMLINK || diff1.newMode === File.modes.SYMLINK) {
        contentChangeDiff = diff2;
      } else {
        contentChangeDiff = diff1;
      }
    }

    if (contentChangeDiff) {
      const filePositions = [...this.diffToFilePosition.values()];
      this.fileTranslations = translatePositionFn(filePositions, contentChangeDiff);

      const hash = crypto.createHash('sha256');
      hash.update(JSON.stringify(Array.from(this.fileTranslations.entries())));
      this.digest = hash.digest('hex');
    } else {
      this.fileTranslations = null;
      this.digest = null;
    }
  }
}
