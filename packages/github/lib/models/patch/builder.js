import PatchBuffer from './patch-buffer';
import Hunk from './hunk';
import File, {nullFile} from './file';
import Patch, {DEFERRED, EXPANDED, REMOVED} from './patch';
import {Unchanged, Addition, Deletion, NoNewline} from './region';
import FilePatch from './file-patch';
import MultiFilePatch from './multi-file-patch';

export const DEFAULT_OPTIONS = {
  // Number of lines after which we consider the diff "large"
  largeDiffThreshold: 800,

  // Map of file path (relative to repository root) to Patch render status (EXPANDED, COLLAPSED, DEFERRED)
  renderStatusOverrides: {},

  // Existing patch buffer to render onto
  patchBuffer: null,

  // Store off what-the-diff file patch
  preserveOriginal: false,

  // Paths of file patches that have been removed from the patch before parsing
  removed: new Set(),
};

export function buildFilePatch(diffs, options) {
  const opts = {...DEFAULT_OPTIONS, ...options};
  const patchBuffer = new PatchBuffer();

  let filePatch;
  if (diffs.length === 0) {
    filePatch = emptyDiffFilePatch();
  } else if (diffs.length === 1) {
    filePatch = singleDiffFilePatch(diffs[0], patchBuffer, opts);
  } else if (diffs.length === 2) {
    filePatch = dualDiffFilePatch(diffs[0], diffs[1], patchBuffer, opts);
  } else {
    throw new Error(`Unexpected number of diffs: ${diffs.length}`);
  }

  // Delete the trailing newline.
  patchBuffer.deleteLastNewline();

  return new MultiFilePatch({patchBuffer, filePatches: [filePatch]});
}

export function buildMultiFilePatch(diffs, options) {
  const opts = {...DEFAULT_OPTIONS, ...options};

  const patchBuffer = new PatchBuffer();

  const byPath = new Map();
  const actions = [];

  let index = 0;
  for (const diff of diffs) {
    const thePath = diff.oldPath || diff.newPath;

    if (diff.status === 'added' || diff.status === 'deleted') {
      // Potential paired diff. Either a symlink deletion + content addition or a symlink addition +
      // content deletion.
      const otherHalf = byPath.get(thePath);
      if (otherHalf) {
        // The second half. Complete the paired diff, or fail if they have unexpected statuses or modes.
        const [otherDiff, otherIndex] = otherHalf;
        actions[otherIndex] = (function(_diff, _otherDiff) {
          return () => dualDiffFilePatch(_diff, _otherDiff, patchBuffer, opts);
        })(diff, otherDiff);
        byPath.delete(thePath);
      } else {
        // The first half we've seen.
        byPath.set(thePath, [diff, index]);
        index++;
      }
    } else {
      actions[index] = (function(_diff) {
        return () => singleDiffFilePatch(_diff, patchBuffer, opts);
      })(diff);
      index++;
    }
  }

  // Populate unpaired diffs that looked like they could be part of a pair, but weren't.
  for (const [unpairedDiff, originalIndex] of byPath.values()) {
    actions[originalIndex] = (function(_unpairedDiff) {
      return () => singleDiffFilePatch(_unpairedDiff, patchBuffer, opts);
    })(unpairedDiff);
  }

  const filePatches = actions.map(action => action());

  // Delete the final trailing newline from the last non-empty patch.
  patchBuffer.deleteLastNewline();

  // Append hidden patches corresponding to each removed file.
  for (const removedPath of opts.removed) {
    const removedFile = new File({path: removedPath});
    const removedMarker = patchBuffer.markPosition(
      Patch.layerName,
      patchBuffer.getBuffer().getEndPosition(),
      {invalidate: 'never', exclusive: false},
    );
    filePatches.push(FilePatch.createHiddenFilePatch(
      removedFile,
      removedFile,
      removedMarker,
      REMOVED,
      /* istanbul ignore next */
      () => { throw new Error(`Attempt to expand removed file patch ${removedPath}`); },
    ));
  }

  return new MultiFilePatch({patchBuffer, filePatches});
}

function emptyDiffFilePatch() {
  return FilePatch.createNull();
}

function singleDiffFilePatch(diff, patchBuffer, opts) {
  const wasSymlink = diff.oldMode === File.modes.SYMLINK;
  const isSymlink = diff.newMode === File.modes.SYMLINK;

  let oldSymlink = null;
  let newSymlink = null;
  if (wasSymlink && !isSymlink) {
    oldSymlink = diff.hunks[0].lines[0].slice(1);
  } else if (!wasSymlink && isSymlink) {
    newSymlink = diff.hunks[0].lines[0].slice(1);
  } else if (wasSymlink && isSymlink) {
    oldSymlink = diff.hunks[0].lines[0].slice(1);
    newSymlink = diff.hunks[0].lines[2].slice(1);
  }

  const oldFile = diff.oldPath !== null || diff.oldMode !== null
    ? new File({path: diff.oldPath, mode: diff.oldMode, symlink: oldSymlink})
    : nullFile;
  const newFile = diff.newPath !== null || diff.newMode !== null
    ? new File({path: diff.newPath, mode: diff.newMode, symlink: newSymlink})
    : nullFile;

  const renderStatusOverride =
    (oldFile.isPresent() && opts.renderStatusOverrides[oldFile.getPath()]) ||
    (newFile.isPresent() && opts.renderStatusOverrides[newFile.getPath()]) ||
    undefined;

  const renderStatus = renderStatusOverride ||
    (isDiffLarge([diff], opts) && DEFERRED) ||
    EXPANDED;

  if (!renderStatus.isVisible()) {
    const patchMarker = patchBuffer.markPosition(
      Patch.layerName,
      patchBuffer.getBuffer().getEndPosition(),
      {invalidate: 'never', exclusive: false},
    );

    return FilePatch.createHiddenFilePatch(
      oldFile, newFile, patchMarker, renderStatus,
      () => {
        const subPatchBuffer = new PatchBuffer();
        const [hunks, nextPatchMarker] = buildHunks(diff, subPatchBuffer);
        const nextPatch = new Patch({status: diff.status, hunks, marker: nextPatchMarker});

        subPatchBuffer.deleteLastNewline();
        return {patch: nextPatch, patchBuffer: subPatchBuffer};
      },
    );
  } else {
    const [hunks, patchMarker] = buildHunks(diff, patchBuffer);
    const patch = new Patch({status: diff.status, hunks, marker: patchMarker});

    const rawPatches = opts.preserveOriginal ? {content: diff} : null;
    return new FilePatch(oldFile, newFile, patch, rawPatches);
  }
}

function dualDiffFilePatch(diff1, diff2, patchBuffer, opts) {
  let modeChangeDiff, contentChangeDiff;
  if (diff1.oldMode === File.modes.SYMLINK || diff1.newMode === File.modes.SYMLINK) {
    modeChangeDiff = diff1;
    contentChangeDiff = diff2;
  } else {
    modeChangeDiff = diff2;
    contentChangeDiff = diff1;
  }

  const filePath = contentChangeDiff.oldPath || contentChangeDiff.newPath;
  const symlink = modeChangeDiff.hunks[0].lines[0].slice(1);

  let status;
  let oldMode, newMode;
  let oldSymlink = null;
  let newSymlink = null;
  if (modeChangeDiff.status === 'added') {
    // contents were deleted and replaced with symlink
    status = 'deleted';
    oldMode = contentChangeDiff.oldMode;
    newMode = modeChangeDiff.newMode;
    newSymlink = symlink;
  } else if (modeChangeDiff.status === 'deleted') {
    // contents were added after symlink was deleted
    status = 'added';
    oldMode = modeChangeDiff.oldMode;
    oldSymlink = symlink;
    newMode = contentChangeDiff.newMode;
  } else {
    throw new Error(`Invalid mode change diff status: ${modeChangeDiff.status}`);
  }

  const oldFile = new File({path: filePath, mode: oldMode, symlink: oldSymlink});
  const newFile = new File({path: filePath, mode: newMode, symlink: newSymlink});

  const renderStatus = opts.renderStatusOverrides[filePath] ||
    (isDiffLarge([contentChangeDiff], opts) && DEFERRED) ||
    EXPANDED;

  if (!renderStatus.isVisible()) {
    const patchMarker = patchBuffer.markPosition(
      Patch.layerName,
      patchBuffer.getBuffer().getEndPosition(),
      {invalidate: 'never', exclusive: false},
    );

    return FilePatch.createHiddenFilePatch(
      oldFile, newFile, patchMarker, renderStatus,
      () => {
        const subPatchBuffer = new PatchBuffer();
        const [hunks, nextPatchMarker] = buildHunks(contentChangeDiff, subPatchBuffer);
        const nextPatch = new Patch({status, hunks, marker: nextPatchMarker});

        subPatchBuffer.deleteLastNewline();
        return {patch: nextPatch, patchBuffer: subPatchBuffer};
      },
    );
  } else {
    const [hunks, patchMarker] = buildHunks(contentChangeDiff, patchBuffer);
    const patch = new Patch({status, hunks, marker: patchMarker});

    const rawPatches = opts.preserveOriginal ? {content: contentChangeDiff, mode: modeChangeDiff} : null;
    return new FilePatch(oldFile, newFile, patch, rawPatches);
  }
}

const CHANGEKIND = {
  '+': Addition,
  '-': Deletion,
  ' ': Unchanged,
  '\\': NoNewline,
};

function buildHunks(diff, patchBuffer) {
  const inserter = patchBuffer.createInserterAtEnd()
    .keepBefore(patchBuffer.findAllMarkers({endPosition: patchBuffer.getInsertionPoint()}));

  let patchMarker = null;
  let firstHunk = true;
  const hunks = [];

  inserter.markWhile(Patch.layerName, () => {
    for (const rawHunk of diff.hunks) {
      let firstRegion = true;
      const regions = [];

      // Separate hunks with an unmarked newline
      if (firstHunk) {
        firstHunk = false;
      } else {
        inserter.insert('\n');
      }

      inserter.markWhile(Hunk.layerName, () => {
        let firstRegionLine = true;
        let currentRegionText = '';
        let CurrentRegionKind = null;

        function finishRegion() {
          if (CurrentRegionKind === null) {
            return;
          }

          // Separate regions with an unmarked newline
          if (firstRegion) {
            firstRegion = false;
          } else {
            inserter.insert('\n');
          }

          inserter.insertMarked(currentRegionText, CurrentRegionKind.layerName, {
            invalidate: 'never',
            exclusive: false,
            callback: (function(_regions, _CurrentRegionKind) {
              return regionMarker => { _regions.push(new _CurrentRegionKind(regionMarker)); };
            })(regions, CurrentRegionKind),
          });
        }

        for (const rawLine of rawHunk.lines) {
          const NextRegionKind = CHANGEKIND[rawLine[0]];
          if (NextRegionKind === undefined) {
            throw new Error(`Unknown diff status character: "${rawLine[0]}"`);
          }
          const nextLine = rawLine.slice(1);

          let separator = '';
          if (firstRegionLine) {
            firstRegionLine = false;
          } else {
            separator = '\n';
          }

          if (NextRegionKind === CurrentRegionKind) {
            currentRegionText += separator + nextLine;

            continue;
          } else {
            finishRegion();

            CurrentRegionKind = NextRegionKind;
            currentRegionText = nextLine;
          }
        }
        finishRegion();
      }, {
        invalidate: 'never',
        exclusive: false,
        callback: (function(_hunks, _rawHunk, _regions) {
          return hunkMarker => {
            _hunks.push(new Hunk({
              oldStartRow: _rawHunk.oldStartLine,
              newStartRow: _rawHunk.newStartLine,
              oldRowCount: _rawHunk.oldLineCount,
              newRowCount: _rawHunk.newLineCount,
              sectionHeading: _rawHunk.heading,
              marker: hunkMarker,
              regions: _regions,
            }));
          };
        })(hunks, rawHunk, regions),
      });
    }
  }, {
    invalidate: 'never',
    exclusive: false,
    callback: marker => { patchMarker = marker; },
  });

  // Separate multiple non-empty patches on the same buffer with an unmarked newline. The newline after the final
  // non-empty patch (if there is one) should be deleted before MultiFilePatch construction.
  if (diff.hunks.length > 0) {
    inserter.insert('\n');
  }

  inserter.apply();

  return [hunks, patchMarker];
}

function isDiffLarge(diffs, opts) {
  const size = diffs.reduce((diffSizeCounter, diff) => {
    return diffSizeCounter + diff.hunks.reduce((hunkSizeCounter, hunk) => {
      return hunkSizeCounter + hunk.lines.length;
    }, 0);
  }, 0);

  return size > opts.largeDiffThreshold;
}
