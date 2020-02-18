import PropTypes from 'prop-types';

export const DOMNodePropType = (props, propName, componentName) => {
  if (props[propName] instanceof HTMLElement) {
    return null;
  } else {
    return new Error(
      `Invalid prop '${propName}' supplied to '${componentName}'. Value is not DOM element.`,
    );
  }
};

export const WorkdirContextPoolPropType = PropTypes.shape({
  getContext: PropTypes.func.isRequired,
});

export const GithubLoginModelPropType = PropTypes.shape({
  getToken: PropTypes.func.isRequired,
  setToken: PropTypes.func.isRequired,
  removeToken: PropTypes.func.isRequired,
  getScopes: PropTypes.func.isRequired,
  onDidUpdate: PropTypes.func.isRequired,
});

export const RemotePropType = PropTypes.shape({
  getName: PropTypes.func.isRequired,
  getUrl: PropTypes.func.isRequired,
  isGithubRepo: PropTypes.func.isRequired,
  getOwner: PropTypes.func.isRequired,
  getRepo: PropTypes.func.isRequired,
  getEndpoint: PropTypes.func.isRequired,
});

export const EndpointPropType = PropTypes.shape({
  getGraphQLRoot: PropTypes.func.isRequired,
  getRestRoot: PropTypes.func.isRequired,
  getRestURI: PropTypes.func.isRequired,
});

export const BranchPropType = PropTypes.shape({
  getName: PropTypes.func.isRequired,
  isDetached: PropTypes.func.isRequired,
  isPresent: PropTypes.func.isRequired,
});

export const SearchPropType = PropTypes.shape({
  getName: PropTypes.func.isRequired,
  createQuery: PropTypes.func.isRequired,
});

export const RemoteSetPropType = PropTypes.shape({
  withName: PropTypes.func.isRequired,
  isEmpty: PropTypes.func.isRequired,
  size: PropTypes.func.isRequired,
  [Symbol.iterator]: PropTypes.func.isRequired,
});

export const BranchSetPropType = PropTypes.shape({
  getNames: PropTypes.func.isRequired,
  getPullTargets: PropTypes.func.isRequired,
  getPushSources: PropTypes.func.isRequired,
});

export const CommitPropType = PropTypes.shape({
  getSha: PropTypes.func.isRequired,
  getMessageSubject: PropTypes.func.isRequired,
  isUnbornRef: PropTypes.func.isRequired,
  isPresent: PropTypes.func.isRequired,
});

export const AuthorPropType = PropTypes.shape({
  getEmail: PropTypes.func.isRequired,
  getFullName: PropTypes.func.isRequired,
  getAvatarUrl: PropTypes.func.isRequired,
});

export const RelayConnectionPropType = nodePropType => PropTypes.shape({
  edges: PropTypes.arrayOf(
    PropTypes.shape({
      cursor: PropTypes.string,
      node: nodePropType,
    }),
  ),
  pageInfo: PropTypes.shape({
    endCursor: PropTypes.string,
    hasNextPage: PropTypes.bool,
    hasPreviousPage: PropTypes.bool,
    startCursor: PropTypes.string,
  }),
  totalCount: PropTypes.number,
});

export const RefHolderPropType = PropTypes.shape({
  isEmpty: PropTypes.func.isRequired,
  get: PropTypes.func.isRequired,
  setter: PropTypes.func.isRequired,
  observe: PropTypes.func.isRequired,
});

export const PointPropType = PropTypes.shape({
  row: PropTypes.number.isRequired,
  column: PropTypes.number.isRequired,
  isEqual: PropTypes.func.isRequired,
});

export const RangePropType = PropTypes.shape({
  start: PointPropType.isRequired,
  end: PointPropType.isRequired,
  isEqual: PropTypes.func.isRequired,
});

export const EnableableOperationPropType = PropTypes.shape({
  isEnabled: PropTypes.func.isRequired,
  run: PropTypes.func.isRequired,
  getMessage: PropTypes.func.isRequired,
  why: PropTypes.func.isRequired,
});

export const OperationStateObserverPropType = PropTypes.shape({
  onDidComplete: PropTypes.func.isRequired,
  dispose: PropTypes.func.isRequired,
});

export const RefresherPropType = PropTypes.shape({
  setRetryCallback: PropTypes.func.isRequired,
  trigger: PropTypes.func.isRequired,
  deregister: PropTypes.func.isRequired,
});

export const IssueishPropType = PropTypes.shape({
  getNumber: PropTypes.func.isRequired,
  getTitle: PropTypes.func.isRequired,
  getGitHubURL: PropTypes.func.isRequired,
  getAuthorLogin: PropTypes.func.isRequired,
  getAuthorAvatarURL: PropTypes.func.isRequired,
  getCreatedAt: PropTypes.func.isRequired,
  getHeadRefName: PropTypes.func.isRequired,
  getHeadRepositoryID: PropTypes.func.isRequired,
  getStatusCounts: PropTypes.func.isRequired,
});

export const FilePatchItemPropType = PropTypes.shape({
  filePath: PropTypes.string.isRequired,
  status: PropTypes.string.isRequired,
});

export const MultiFilePatchPropType = PropTypes.shape({
  getFilePatches: PropTypes.func.isRequired,
});

const statusNames = [
  'added',
  'deleted',
  'modified',
  'typechange',
  'equivalent',
];

export const MergeConflictItemPropType = PropTypes.shape({
  filePath: PropTypes.string.isRequired,
  status: PropTypes.shape({
    file: PropTypes.oneOf(statusNames).isRequired,
    ours: PropTypes.oneOf(statusNames).isRequired,
    theirs: PropTypes.oneOf(statusNames).isRequired,
  }).isRequired,
});

export const UserStorePropType = PropTypes.shape({
  getUsers: PropTypes.func.isRequired,
  onDidUpdate: PropTypes.func.isRequired,
});

// Require item classes lazily to prevent circular imports
let lazyItemConstructors = null;
function createItemTypePropType(required) {
  return function(props, propName, componentName) {
    if (lazyItemConstructors === null) {
      lazyItemConstructors = new Set();
      for (const itemPath of [
        './items/changed-file-item',
        './items/commit-preview-item',
        './items/commit-detail-item',
        './items/issueish-detail-item',
      ]) {
        lazyItemConstructors.add(require(itemPath).default);
      }
    }

    if (props[propName] === undefined || props[propName] === null) {
      /* istanbul ignore else */
      if (required) {
        return new Error(`Missing required prop ${propName} on component ${componentName}.`);
      } else {
        return undefined;
      }
    }

    /* istanbul ignore if */
    if (!lazyItemConstructors.has(props[propName])) {
      const choices = Array.from(lazyItemConstructors, each => each.name).join(', ');
      return new Error(
        `Invalid prop "${propName}" supplied to ${componentName}. Must be one of ${choices}.`);
    }

    return undefined;
  };
}

export const ItemTypePropType = createItemTypePropType(false);
ItemTypePropType.isRequired = createItemTypePropType(true);
