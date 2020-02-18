import {
  buildStatusFromStatusContext,
  buildStatusFromCheckResult,
  combineBuildStatuses,
} from '../../lib/models/build-status';

describe('BuildStatus', function() {
  it('interprets an EXPECTED status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'EXPECTED'}), {
      icon: 'primitive-dot',
      classSuffix: 'pending',
    });
  });

  it('interprets a PENDING status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'PENDING'}), {
      icon: 'primitive-dot',
      classSuffix: 'pending',
    });
  });

  it('interprets a SUCCESS status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'SUCCESS'}), {
      icon: 'check',
      classSuffix: 'success',
    });
  });

  it('interprets an ERROR status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'ERROR'}), {
      icon: 'alert',
      classSuffix: 'failure',
    });
  });

  it('interprets a FAILURE status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'FAILURE'}), {
      icon: 'x',
      classSuffix: 'failure',
    });
  });

  it('interprets an unexpected status context', function() {
    assert.deepEqual(buildStatusFromStatusContext({state: 'UNEXPECTED'}), {
      icon: 'unverified',
      classSuffix: 'pending',
    });
  });

  it('interprets a QUEUED check result', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'QUEUED'}), {
      icon: 'primitive-dot',
      classSuffix: 'pending',
    });
  });

  it('interprets a REQUESTED check result', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'REQUESTED'}), {
      icon: 'primitive-dot',
      classSuffix: 'pending',
    });
  });

  it('interprets an IN_PROGRESS check result', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'IN_PROGRESS'}), {
      icon: 'primitive-dot',
      classSuffix: 'pending',
    });
  });

  it('interprets a SUCCESS check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'SUCCESS'}), {
      icon: 'check',
      classSuffix: 'success',
    });
  });

  it('interprets a FAILURE check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'FAILURE'}), {
      icon: 'x',
      classSuffix: 'failure',
    });
  });

  it('interprets a TIMED_OUT check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'TIMED_OUT'}), {
      icon: 'alert',
      classSuffix: 'failure',
    });
  });

  it('interprets a CANCELLED check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'CANCELLED'}), {
      icon: 'alert',
      classSuffix: 'failure',
    });
  });

  it('interprets an ACTION_REQUIRED check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'ACTION_REQUIRED'}), {
      icon: 'bell',
      classSuffix: 'failure',
    });
  });

  it('interprets a NEUTRAL check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'NEUTRAL'}), {
      icon: 'dash',
      classSuffix: 'neutral',
    });
  });

  it('interprets an unexpected check status', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'WAT'}), {
      icon: 'unverified',
      classSuffix: 'pending',
    });
  });

  it('interprets an unexpected check conclusion', function() {
    assert.deepEqual(buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'HUH'}), {
      icon: 'unverified',
      classSuffix: 'pending',
    });
  });

  describe('combine', function() {
    const actionRequireds = [
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'ACTION_REQUIRED'}),
    ];
    const pendings = [
      buildStatusFromCheckResult({status: 'QUEUED'}),
      buildStatusFromCheckResult({status: 'IN_PROGRESS'}),
      buildStatusFromCheckResult({status: 'REQUESTED'}),
      buildStatusFromStatusContext({state: 'EXPECTED'}),
      buildStatusFromStatusContext({state: 'PENDING'}),
    ];
    const errors = [
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'TIMED_OUT'}),
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'CANCELLED'}),
      buildStatusFromStatusContext({state: 'ERROR'}),
    ];
    const failures = [
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'FAILURE'}),
      buildStatusFromStatusContext({state: 'FAILURE'}),
    ];
    const successes = [
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'SUCCESS'}),
      buildStatusFromStatusContext({state: 'SUCCESS'}),
    ];
    const neutrals = [
      buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'NEUTRAL'}),
    ];

    it('combines nothing into NEUTRAL', function() {
      assert.deepEqual(combineBuildStatuses(), {
        icon: 'dash',
        classSuffix: 'neutral',
      });
    });

    it('combines anything and ACTION_REQUIRED into ACTION_REQUIRED', function() {
      const all = [
        ...actionRequireds,
        ...pendings,
        ...errors,
        ...failures,
        ...successes,
        ...neutrals,
      ];

      const actionRequired = buildStatusFromCheckResult({status: 'COMPLETED', conclusion: 'ACTION_REQUIRED'});
      for (const buildStatus of all) {
        assert.deepEqual(combineBuildStatuses(buildStatus, actionRequired), {
          icon: 'bell',
          classSuffix: 'failure',
        });

        assert.deepEqual(combineBuildStatuses(actionRequired, buildStatus), {
          icon: 'bell',
          classSuffix: 'failure',
        });
      }
    });

    it('combines anything but ACTION_REQUIRED and ERROR into ERROR', function() {
      const rest = [
        ...errors,
        ...pendings,
        ...failures,
        ...successes,
        ...neutrals,
      ];

      for (const errorStatus of errors) {
        for (const otherStatus of rest) {
          assert.deepEqual(combineBuildStatuses(otherStatus, errorStatus), {
            icon: 'alert',
            classSuffix: 'failure',
          });

          assert.deepEqual(combineBuildStatuses(errorStatus, otherStatus), {
            icon: 'alert',
            classSuffix: 'failure',
          });
        }
      }
    });

    it('combines anything but ACTION_REQUIRED or ERROR and FAILURE into FAILURE', function() {
      const rest = [
        ...pendings,
        ...failures,
        ...successes,
        ...neutrals,
      ];

      for (const failureStatus of failures) {
        for (const otherStatus of rest) {
          assert.deepEqual(combineBuildStatuses(otherStatus, failureStatus), {
            icon: 'x',
            classSuffix: 'failure',
          });

          assert.deepEqual(combineBuildStatuses(failureStatus, otherStatus), {
            icon: 'x',
            classSuffix: 'failure',
          });
        }
      }
    });

    it('combines anything but ACTION_REQUIRED, ERROR, or FAILURE and PENDING into PENDING', function() {
      const rest = [
        ...pendings,
        ...successes,
        ...neutrals,
      ];

      for (const pendingStatus of pendings) {
        for (const otherStatus of rest) {
          assert.deepEqual(combineBuildStatuses(otherStatus, pendingStatus), {
            icon: 'primitive-dot',
            classSuffix: 'pending',
          });

          assert.deepEqual(combineBuildStatuses(pendingStatus, otherStatus), {
            icon: 'primitive-dot',
            classSuffix: 'pending',
          });
        }
      }
    });

    it('combines SUCCESSes into SUCCESS', function() {
      const rest = [
        ...successes,
        ...neutrals,
      ];

      for (const successStatus of successes) {
        for (const otherStatus of rest) {
          assert.deepEqual(combineBuildStatuses(otherStatus, successStatus), {
            icon: 'check',
            classSuffix: 'success',
          });

          assert.deepEqual(combineBuildStatuses(successStatus, otherStatus), {
            icon: 'check',
            classSuffix: 'success',
          });
        }
      }
    });

    it('ignores NEUTRAL', function() {
      const all = [
        ...actionRequireds,
        ...pendings,
        ...errors,
        ...failures,
        ...successes,
        ...neutrals,
      ];

      for (const neutralStatus of neutrals) {
        for (const otherStatus of all) {
          assert.deepEqual(combineBuildStatuses(otherStatus, neutralStatus), otherStatus);
          assert.deepEqual(combineBuildStatuses(neutralStatus, otherStatus), otherStatus);
        }
      }
    });

    it('combines NEUTRALs into NEUTRAL', function() {
      assert.deepEqual(combineBuildStatuses(neutrals[0], neutrals[0]), {
        icon: 'dash',
        classSuffix: 'neutral',
      });
    });
  });
});
