import path from 'path';
import fs from 'fs-extra';
import os from 'os';
import temp from 'temp';

import RefHolder from './models/ref-holder';
import Author from './models/author';

export const LINE_ENDING_REGEX = /\r?\n/;
export const CO_AUTHOR_REGEX = /^co-authored-by. (.+?) <(.+?)>$/i;
export const PAGE_SIZE = 50;
export const PAGINATION_WAIT_TIME_MS = 100;
export const CHECK_SUITE_PAGE_SIZE = 10;
export const CHECK_RUN_PAGE_SIZE = 20;

export function autobind(self, ...methods) {
  for (const method of methods) {
    if (typeof self[method] !== 'function') {
      throw new Error(`Unable to autobind method ${method}`);
    }
    self[method] = self[method].bind(self);
  }
}

// Extract a subset of props chosen from a propTypes object from a component's props to pass to a different API.
//
// Usage:
//
// ```js
// const apiProps = {
//   zero: PropTypes.number.isRequired,
//   one: PropTypes.string,
//   two: PropTypes.object,
// };
//
// class Component extends React.Component {
//   static propTypes = {
//     ...apiProps,
//     extra: PropTypes.func,
//   }
//
//   action() {
//     const options = extractProps(this.props, apiProps);
//     // options contains zero, one, and two, but not extra
//   }
// }
// ```
export function extractProps(props, propTypes, nameMap = {}) {
  return Object.keys(propTypes).reduce((opts, propName) => {
    if (props[propName] !== undefined) {
      const destPropName = nameMap[propName] || propName;
      opts[destPropName] = props[propName];
    }
    return opts;
  }, {});
}

// The opposite of extractProps. Return a subset of props that do *not* appear in a component's prop types.
export function unusedProps(props, propTypes) {
  return Object.keys(props).reduce((opts, propName) => {
    if (propTypes[propName] === undefined) {
      opts[propName] = props[propName];
    }
    return opts;
  }, {});
}

export function getPackageRoot() {
  const {resourcePath} = atom.getLoadSettings();
  const currentFileWasRequiredFromSnapshot = !path.isAbsolute(__dirname);
  if (currentFileWasRequiredFromSnapshot) {
    return path.join(resourcePath, 'node_modules', 'github');
  } else {
    const packageRoot = path.resolve(__dirname, '..');
    if (path.extname(resourcePath) === '.asar') {
      if (packageRoot.indexOf(resourcePath) === 0) {
        return path.join(`${resourcePath}.unpacked`, 'node_modules', 'github');
      }
    }
    return packageRoot;
  }
}

function getAtomAppName() {
  const match = atom.getVersion().match(/-([A-Za-z]+)(\d+|-)/);
  if (match) {
    const channel = match[1];
    return `Atom ${channel.charAt(0).toUpperCase() + channel.slice(1)} Helper`;
  }

  return 'Atom Helper';
}

export function getAtomHelperPath() {
  if (process.platform === 'darwin') {
    const appName = getAtomAppName();
    return path.resolve(process.resourcesPath, '..', 'Frameworks',
      `${appName}.app`, 'Contents', 'MacOS', appName);
  } else {
    return process.execPath;
  }
}

let DUGITE_PATH;
export function getDugitePath() {
  if (!DUGITE_PATH) {
    DUGITE_PATH = require.resolve('dugite');
    if (!path.isAbsolute(DUGITE_PATH)) {
      // Assume we're snapshotted
      const {resourcePath} = atom.getLoadSettings();
      if (path.extname(resourcePath) === '.asar') {
        DUGITE_PATH = path.join(`${resourcePath}.unpacked`, 'node_modules', 'dugite');
      } else {
        DUGITE_PATH = path.join(resourcePath, 'node_modules', 'dugite');
      }
    }
  }

  return DUGITE_PATH;
}

const SHARED_MODULE_PATHS = new Map();
export function getSharedModulePath(relPath) {
  let modulePath = SHARED_MODULE_PATHS.get(relPath);
  if (!modulePath) {
    modulePath = require.resolve(path.join(__dirname, 'shared', relPath));
    if (!path.isAbsolute(modulePath)) {
      // Assume we're snapshotted
      const {resourcePath} = atom.getLoadSettings();
      modulePath = path.join(resourcePath, modulePath);
    }

    SHARED_MODULE_PATHS.set(relPath, modulePath);
  }

  return modulePath;
}

export function isBinary(data) {
  for (let i = 0; i < 50; i++) {
    const code = data.charCodeAt(i);
    // Char code 65533 is the "replacement character";
    // 8 and below are control characters.
    if (code === 65533 || code < 9) {
      return true;
    }
  }

  return false;
}

function descriptorsFromProto(proto) {
  return Object.getOwnPropertyNames(proto).reduce((acc, name) => {
    Object.assign(acc, {
      [name]: Reflect.getOwnPropertyDescriptor(proto, name),
    });
    return acc;
  }, {});
}

/**
 * Takes an array of targets and returns a proxy. The proxy intercepts property accessor calls and
 * returns the value of that property on the first object in `targets` where the target implements that property.
 */
export function firstImplementer(...targets) {
  return new Proxy({__implementations: targets}, {
    get(target, name) {
      if (name === 'getImplementers') {
        return () => targets;
      }

      if (Reflect.has(target, name)) {
        return target[name];
      }

      const firstValidTarget = targets.find(t => Reflect.has(t, name));
      if (firstValidTarget) {
        return firstValidTarget[name];
      } else {
        return undefined;
      }
    },

    set(target, name, value) {
      const firstValidTarget = targets.find(t => Reflect.has(t, name));
      if (firstValidTarget) {
        // eslint-disable-next-line no-return-assign
        return firstValidTarget[name] = value;
      } else {
        // eslint-disable-next-line no-return-assign
        return target[name] = value;
      }
    },

    // Used by sinon
    has(target, name) {
      if (name === 'getImplementers') {
        return true;
      }

      return targets.some(t => Reflect.has(t, name));
    },

    // Used by sinon
    getOwnPropertyDescriptor(target, name) {
      const firstValidTarget = targets.find(t => Reflect.getOwnPropertyDescriptor(t, name));
      const compositeOwnPropertyDescriptor = Reflect.getOwnPropertyDescriptor(target, name);
      if (firstValidTarget) {
        return Reflect.getOwnPropertyDescriptor(firstValidTarget, name);
      } else if (compositeOwnPropertyDescriptor) {
        return compositeOwnPropertyDescriptor;
      } else {
        return undefined;
      }
    },

    // Used by sinon
    getPrototypeOf(target) {
      return targets.reduceRight((acc, t) => {
        return Object.create(acc, descriptorsFromProto(Object.getPrototypeOf(t)));
      }, Object.prototype);
    },
  });
}

function isRoot(dir) {
  return path.resolve(dir, '..') === dir;
}

export function isValidWorkdir(dir) {
  return dir !== os.homedir() && !isRoot(dir);
}

export async function fileExists(absoluteFilePath) {
  try {
    await fs.access(absoluteFilePath);
    return true;
  } catch (e) {
    if (e.code === 'ENOENT') {
      return false;
    }

    throw e;
  }
}

export function getTempDir(options = {}) {
  temp.track();

  return new Promise((resolve, reject) => {
    temp.mkdir(options, (tempError, folder) => {
      if (tempError) {
        reject(tempError);
        return;
      }

      if (options.symlinkOk) {
        resolve(folder);
      } else {
        fs.realpath(folder, (realError, rpath) => (realError ? reject(realError) : resolve(rpath)));
      }
    });
  });
}

export async function isFileExecutable(absoluteFilePath) {
  const stat = await fs.stat(absoluteFilePath);
  return stat.mode & fs.constants.S_IXUSR; // eslint-disable-line no-bitwise
}

export async function isFileSymlink(absoluteFilePath) {
  const stat = await fs.lstat(absoluteFilePath);
  return stat.isSymbolicLink();
}

export function shortenSha(sha) {
  return sha.slice(0, 8);
}

export const classNameForStatus = {
  added: 'added',
  deleted: 'removed',
  modified: 'modified',
  typechange: 'modified',
  equivalent: 'ignored',
};

/*
 * Apply any platform-specific munging to a path before presenting it as
 * a git environment variable or option.
 *
 * Convert a Windows-style "C:\foo\bar\baz" path to a "/c/foo/bar/baz" UNIX-y
 * path that the sh.exe used to execute git's credential helpers will
 * understand.
 */
export function normalizeGitHelperPath(inPath) {
  if (process.platform === 'win32') {
    return inPath.replace(/\\/g, '/').replace(/^([^:]+):/, '/$1');
  } else {
    return inPath;
  }
}

/*
 * On Windows, git commands report paths with / delimiters. Convert them to \-delimited paths
 * so that Atom unifromly treats paths with native path separators.
 */
export function toNativePathSep(rawPath) {
  if (process.platform !== 'win32') {
    return rawPath;
  } else {
    return rawPath.split('/').join(path.sep);
  }
}

/*
 * Convert Windows paths back to /-delimited paths to be presented to git.
 */
export function toGitPathSep(rawPath) {
  if (process.platform !== 'win32') {
    return rawPath;
  } else {
    return rawPath.split(path.sep).join('/');
  }
}

export function filePathEndsWith(filePath, ...segments) {
  return filePath.endsWith(path.join(...segments));
}

/**
 * Turns an array of things @kuychaco cannot eat
 * into a sentence containing things @kuychaco cannot eat
 *
 * ['toast'] => 'toast'
 * ['toast', 'eggs'] => 'toast and eggs'
 * ['toast', 'eggs', 'cheese'] => 'toast, eggs, and cheese'
 *
 * Oxford comma included because you're wrong, shut up.
 */
export function toSentence(array) {
  const len = array.length;
  if (len === 1) {
    return `${array[0]}`;
  } else if (len === 2) {
    return `${array[0]} and ${array[1]}`;
  }

  return array.reduce((acc, item, idx) => {
    if (idx === 0) {
      return `${item}`;
    } else if (idx === len - 1) {
      return `${acc}, and ${item}`;
    } else {
      return `${acc}, ${item}`;
    }
  }, '');
}

export function pushAtKey(map, key, value) {
  let existing = map.get(key);
  if (!existing) {
    existing = [];
    map.set(key, existing);
  }
  existing.push(value);
}

// Repository and workspace helpers

export function getCommitMessagePath(repository) {
  return path.join(repository.getGitDirectoryPath(), 'ATOM_COMMIT_EDITMSG');
}

export function getCommitMessageEditors(repository, workspace) {
  if (!repository.isPresent()) {
    return [];
  }
  return workspace.getTextEditors().filter(editor => editor.getPath() === getCommitMessagePath(repository));
}

let ChangedFileItem = null;
export function getFilePatchPaneItems({onlyStaged, empty} = {}, workspace) {
  if (ChangedFileItem === null) {
    ChangedFileItem = require('./items/changed-file-item').default;
  }

  return workspace.getPaneItems().filter(item => {
    const isFilePatchItem = item && item.getRealItem && item.getRealItem() instanceof ChangedFileItem;
    if (onlyStaged) {
      return isFilePatchItem && item.stagingStatus === 'staged';
    } else if (empty) {
      return isFilePatchItem ? item.isEmpty() : false;
    } else {
      return isFilePatchItem;
    }
  });
}

export function destroyFilePatchPaneItems({onlyStaged} = {}, workspace) {
  const itemsToDestroy = getFilePatchPaneItems({onlyStaged}, workspace);
  itemsToDestroy.forEach(item => item.destroy());
}

export function destroyEmptyFilePatchPaneItems(workspace) {
  const itemsToDestroy = getFilePatchPaneItems({empty: true}, workspace);
  itemsToDestroy.forEach(item => item.destroy());
}

export function extractCoAuthorsAndRawCommitMessage(commitMessage) {
  const messageLines = [];
  const coAuthors = [];

  for (const line of commitMessage.split(LINE_ENDING_REGEX)) {
    const match = line.match(CO_AUTHOR_REGEX);
    if (match) {
      // eslint-disable-next-line no-unused-vars
      const [_, name, email] = match;
      coAuthors.push(new Author(email, name));
    } else {
      messageLines.push(line);
    }
  }

  return {message: messageLines.join('\n'), coAuthors};
}

// Atom API pane item manipulation

export function createItem(node, componentHolder = null, uri = null, extra = {}) {
  const holder = componentHolder || new RefHolder();

  const override = {
    getElement: () => node,

    getRealItem: () => holder.getOr(null),

    getRealItemPromise: () => holder.getPromise(),

    ...extra,
  };

  if (uri) {
    override.getURI = () => uri;
  }

  if (componentHolder) {
    return new Proxy(override, {
      get(target, name) {
        if (Reflect.has(target, name)) {
          return target[name];
        }

        // The {value: ...} wrapper prevents .map() from flattening a returned RefHolder.
        // If component[name] is a RefHolder, we want to return that RefHolder as-is.
        const {value} = holder.map(component => ({value: component[name]})).getOr({value: undefined});
        return value;
      },

      set(target, name, value) {
        return holder.map(component => {
          component[name] = value;
          return true;
        }).getOr(true);
      },

      has(target, name) {
        return holder.map(component => Reflect.has(component, name)).getOr(false) || Reflect.has(target, name);
      },
    });
  } else {
    return override;
  }
}

// Set functions

export function equalSets(left, right) {
  if (left.size !== right.size) {
    return false;
  }

  for (const each of left) {
    if (!right.has(each)) {
      return false;
    }
  }

  return true;
}

// Constants

export const NBSP_CHARACTER = '\u00a0';

export function blankLabel() {
  return NBSP_CHARACTER;
}

export const reactionTypeToEmoji = {
  THUMBS_UP: '👍',
  THUMBS_DOWN: '👎',
  LAUGH: '😆',
  HOORAY: '🎉',
  CONFUSED: '😕',
  HEART: '❤️',
  ROCKET: '🚀',
  EYES: '👀',
};

// Markdown

let marked = null;
let domPurify = null;

export function renderMarkdown(md) {
  if (marked === null) {
    marked = require('marked');

    if (domPurify === null) {
      const createDOMPurify = require('dompurify');
      domPurify = createDOMPurify();
    }

    marked.setOptions({
      silent: true,
      sanitize: true,
      sanitizer: html => domPurify.sanitize(html),
    });
  }

  return marked(md);
}

export const GHOST_USER = {
  login: 'ghost',
  avatarUrl: 'https://avatars1.githubusercontent.com/u/10137?v=4',
  url: 'https://github.com/ghost',
};
