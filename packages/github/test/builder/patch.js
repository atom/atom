// Builders for classes related to MultiFilePatches.

import {buildMultiFilePatch} from '../../lib/models/patch/builder';
import {EXPANDED} from '../../lib/models/patch/patch';
import File from '../../lib/models/patch/file';

const UNSET = Symbol('unset');

class MultiFilePatchBuilder {
  constructor() {
    this.rawFilePatches = [];
    this.renderStatusOverrides = {};
  }

  addFilePatch(block = () => {}) {
    const filePatch = new FilePatchBuilder();
    block(filePatch);
    const {raw, renderStatusOverrides} = filePatch.build();
    this.rawFilePatches.push(raw);
    this.renderStatusOverrides = Object.assign(this.renderStatusOverrides, renderStatusOverrides);
    return this;
  }

  build(opts = {}) {
    const raw = this.rawFilePatches;
    const multiFilePatch = buildMultiFilePatch(raw, {
      renderStatusOverrides: this.renderStatusOverrides,
      ...opts,
    });
    return {raw, multiFilePatch};
  }
}

class FilePatchBuilder {
  constructor() {
    this._oldPath = 'file';
    this._oldMode = File.modes.NORMAL;
    this._oldSymlink = null;

    this._newPath = UNSET;
    this._newMode = UNSET;
    this._newSymlink = null;

    this.patchBuilder = new PatchBuilder();
  }

  setOldFile(block) {
    const file = new FileBuilder();
    block(file);
    const rawFile = file.build();
    this._oldPath = rawFile.path;
    this._oldMode = rawFile.mode;
    if (rawFile.symlink) {
      this.empty();
      this._oldSymlink = rawFile.symlink;
    }
    return this;
  }

  nullOldFile() {
    this._oldPath = null;
    this._oldMode = null;
    this._oldSymlink = null;
    return this;
  }

  setNewFile(block) {
    const file = new FileBuilder();
    block(file);
    const rawFile = file.build();
    this._newPath = rawFile.path;
    this._newMode = rawFile.mode;
    if (rawFile.symlink) {
      this.empty();
      this._newSymlink = rawFile.symlink;
    }
    return this;
  }

  nullNewFile() {
    this._newPath = null;
    this._newMode = null;
    this._newSymlink = null;
    return this;
  }

  status(...args) {
    this.patchBuilder.status(...args);
    return this;
  }

  renderStatus(...args) {
    this.patchBuilder.renderStatus(...args);
    return this;
  }

  addHunk(...args) {
    this.patchBuilder.addHunk(...args);
    return this;
  }

  empty() {
    this.patchBuilder.empty();
    return this;
  }

  build(opts = {}) {
    const {raw: rawPatch} = this.patchBuilder.build();
    const renderStatusOverrides = {};
    renderStatusOverrides[this._oldPath] = rawPatch.renderStatus;

    if (this._newPath === UNSET) {
      this._newPath = this._oldPath;
    }

    if (this._newMode === UNSET) {
      this._newMode = this._oldMode;
    }

    if (this._oldSymlink !== null || this._newSymlink !== null) {
      if (rawPatch.hunks.length > 0) {
        throw new Error('Cannot have both a symlink target and hunk content');
      }

      const hb = new HunkBuilder();
      if (this._oldSymlink !== null) {
        hb.deleted(this._oldSymlink);
        hb.noNewline();
      }
      if (this._newSymlink !== null) {
        hb.added(this._newSymlink);
        hb.noNewline();
      }

      rawPatch.hunks = [hb.build().raw];
    }

    const option = {
      renderStatusOverrides,
      ...opts,
    };

    const raw = {
      oldPath: this._oldPath,
      oldMode: this._oldMode,
      newPath: this._newPath,
      newMode: this._newMode,
      ...rawPatch,
    };

    const mfp = buildMultiFilePatch([raw], option);
    const [filePatch] = mfp.getFilePatches();

    return {
      raw,
      filePatch,
      renderStatusOverrides,
    };
  }
}

class FileBuilder {
  constructor() {
    this._path = 'file.txt';
    this._mode = File.modes.NORMAL;
    this._symlink = null;
  }

  path(thePath) {
    this._path = thePath;
    return this;
  }

  mode(theMode) {
    this._mode = theMode;
    return this;
  }

  executable() {
    return this.mode(File.modes.EXECUTABLE);
  }

  symlinkTo(destinationPath) {
    this._symlink = destinationPath;
    return this.mode(File.modes.SYMLINK);
  }

  build() {
    return {path: this._path, mode: this._mode, symlink: this._symlink};
  }
}

class PatchBuilder {
  constructor() {
    this._status = 'modified';
    this._renderStatus = EXPANDED;
    this.rawHunks = [];
    this.drift = 0;
    this.explicitlyEmpty = false;
  }

  status(st) {
    if (['modified', 'added', 'deleted', 'renamed'].indexOf(st) === -1) {
      throw new Error(`Unrecognized status: ${st} (must be 'modified', 'added' or 'deleted')`);
    }

    this._status = st;
    return this;
  }

  renderStatus(status) {
    this._renderStatus = status;
    return this;
  }

  addHunk(block = () => {}) {
    const builder = new HunkBuilder(this.drift);
    block(builder);
    const {raw, drift} = builder.build();
    this.rawHunks.push(raw);
    this.drift = drift;
    return this;
  }

  empty() {
    this.explicitlyEmpty = true;
    return this;
  }

  build(opt = {}) {
    if (this.rawHunks.length === 0 && !this.explicitlyEmpty) {
      if (this._status === 'modified') {
        this.addHunk(hunk => hunk.oldRow(1).unchanged('0000').added('0001').deleted('0002').unchanged('0003'));
        this.addHunk(hunk => hunk.oldRow(10).unchanged('0004').added('0005').deleted('0006').unchanged('0007'));
      } else if (this._status === 'added') {
        this.addHunk(hunk => hunk.oldRow(1).added('0000', '0001', '0002', '0003'));
      } else if (this._status === 'deleted') {
        this.addHunk(hunk => hunk.oldRow(1).deleted('0000', '0001', '0002', '0003'));
      }
    }

    const raw = {
      status: this._status,
      hunks: this.rawHunks,
      renderStatus: this._renderStatus,
    };

    const mfp = buildMultiFilePatch([{
      oldPath: 'file',
      oldMode: File.modes.NORMAL,
      newPath: 'file',
      newMode: File.modes.NORMAL,
      ...raw,
    }], {
      renderStatusOverrides: {file: this._renderStatus},
      ...opt,
    });
    const [filePatch] = mfp.getFilePatches();
    const patch = filePatch.getPatch();

    return {raw, patch};
  }
}

class HunkBuilder {
  constructor(drift = 0) {
    this.drift = drift;

    this.oldStartRow = 0;
    this.oldRowCount = null;
    this.newStartRow = null;
    this.newRowCount = null;

    this.sectionHeading = "don't care";

    this.lines = [];
  }

  oldRow(rowNumber) {
    this.oldStartRow = rowNumber;
    return this;
  }

  unchanged(...lines) {
    for (const line of lines) {
      this.lines.push(` ${line}`);
    }
    return this;
  }

  added(...lines) {
    for (const line of lines) {
      this.lines.push(`+${line}`);
    }
    return this;
  }

  deleted(...lines) {
    for (const line of lines) {
      this.lines.push(`-${line}`);
    }
    return this;
  }

  noNewline() {
    this.lines.push('\\ No newline at end of file');
    return this;
  }

  build() {
    if (this.lines.length === 0) {
      this.unchanged('0000').added('0001').deleted('0002').unchanged('0003');
    }

    if (this.oldRowCount === null) {
      this.oldRowCount = this.lines.filter(line => /^[ -]/.test(line)).length;
    }

    if (this.newStartRow === null) {
      this.newStartRow = this.oldStartRow + this.drift;
    }

    if (this.newRowCount === null) {
      this.newRowCount = this.lines.filter(line => /^[ +]/.test(line)).length;
    }

    const raw = {
      oldStartLine: this.oldStartRow,
      oldLineCount: this.oldRowCount,
      newStartLine: this.newStartRow,
      newLineCount: this.newRowCount,
      heading: this.sectionHeading,
      lines: this.lines,
    };

    const mfp = buildMultiFilePatch([{
      oldPath: 'file',
      oldMode: File.modes.NORMAL,
      newPath: 'file',
      newMode: File.modes.NORMAL,
      status: 'modified',
      hunks: [raw],
    }]);
    const [fp] = mfp.getFilePatches();
    const [hunk] = fp.getHunks();

    return {
      raw,
      hunk,
      drift: this.drift + this.newRowCount - this.oldRowCount,
    };
  }
}

export function multiFilePatchBuilder() {
  return new MultiFilePatchBuilder();
}

export function filePatchBuilder() {
  return new FilePatchBuilder();
}

export function patchBuilder() {
  return new PatchBuilder();
}

export function hunkBuilder() {
  return new HunkBuilder();
}
