// Commit or pull request build status, unified from those derived from the Checks API and the Status API.

const DEFAULT = {
  icon: 'unverified',
  classSuffix: 'pending',
};

const PENDING = {
  icon: 'primitive-dot',
  classSuffix: 'pending',
};

const SUCCESS = {
  icon: 'check',
  classSuffix: 'success',
};

const FAILURE = {
  icon: 'x',
  classSuffix: 'failure',
};

const ERROR = {
  icon: 'alert',
  classSuffix: 'failure',
};

const ACTION_REQUIRED = {
  icon: 'bell',
  classSuffix: 'failure',
};

const NEUTRAL = {
  icon: 'dash',
  classSuffix: 'neutral',
};

const STATUS_CONTEXT_MAP = {
  EXPECTED: PENDING, PENDING, SUCCESS, ERROR, FAILURE,
};

export function buildStatusFromStatusContext({state}) {
  return STATUS_CONTEXT_MAP[state] || DEFAULT;
}

const PENDING_CHECK_STATUSES = new Set(['QUEUED', 'IN_PROGRESS', 'REQUESTED']);

const COMPLETED_CHECK_CONCLUSION_MAP = {
  SUCCESS, FAILURE, TIMED_OUT: ERROR, CANCELLED: ERROR, ACTION_REQUIRED, NEUTRAL,
};

export function buildStatusFromCheckResult({status, conclusion}) {
  if (PENDING_CHECK_STATUSES.has(status)) {
    return PENDING;
  } else if (status === 'COMPLETED') {
    return COMPLETED_CHECK_CONCLUSION_MAP[conclusion] || DEFAULT;
  } else {
    return DEFAULT;
  }
}

const STATUS_PRIORITY = [
  DEFAULT,
  NEUTRAL,
  SUCCESS,
  PENDING,
  FAILURE,
  ERROR,
  ACTION_REQUIRED,
];

export function combineBuildStatuses(...statuses) {
  let highestPriority = 0;
  let highestPriorityStatus = NEUTRAL;
  for (const status of statuses) {
    const priority = STATUS_PRIORITY.indexOf(status);
    if (priority > highestPriority) {
      highestPriority = priority;
      highestPriorityStatus = status;
    }
  }
  return highestPriorityStatus;
}
