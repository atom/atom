import path from 'path';
import fs from 'fs-extra';

import CompositeGitStrategy from '../composite-git-strategy';
import {toNativePathSep} from '../helpers';

/**
 * Locate the nearest git working directory above a given starting point, caching results.
 */
export default class WorkdirCache {
  constructor(maxSize = 1000) {
    this.maxSize = maxSize;
    this.known = new Map();
  }

  async find(startPath) {
    const cached = this.known.get(startPath);
    if (cached !== undefined) {
      return cached;
    }

    const workDir = await this.revParse(startPath);

    if (this.known.size >= this.maxSize) {
      this.known.clear();
    }
    this.known.set(startPath, workDir);

    return workDir;
  }

  invalidate() {
    this.known.clear();
  }

  async revParse(startPath) {
    try {
      const startDir = (await fs.stat(startPath)).isDirectory() ? startPath : path.dirname(startPath);

      // Within a git worktree, return a non-empty string containing the path to the worktree root.
      // Within a gitdir or outside of a worktree, return an empty string.
      // Throw if startDir does not exist.
      const topLevel = await CompositeGitStrategy.create(startDir).exec(['rev-parse', '--show-toplevel']);
      if (/\S/.test(topLevel)) {
        return toNativePathSep(topLevel.trim());
      }

      // Within a gitdir, return the absolute path to the gitdir.
      // Outside of a gitdir or worktree, throw.
      const gitDir = await CompositeGitStrategy.create(startDir).exec(['rev-parse', '--absolute-git-dir']);
      return this.revParse(path.resolve(gitDir, '..'));
    } catch (e) {
      /* istanbul ignore if */
      if (atom.config.get('github.reportCannotLocateWorkspaceError')) {
        // eslint-disable-next-line no-console
        console.error(
          `Unable to locate git workspace root for ${startPath}. Expected if ${startPath} is not in a git repository.`,
          e,
        );
      }
      return null;
    }
  }
}
