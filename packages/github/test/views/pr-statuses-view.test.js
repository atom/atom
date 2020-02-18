import React from 'react';
import {shallow} from 'enzyme';

import {BarePrStatusesView} from '../../lib/views/pr-statuses-view';
import CheckSuitesAccumulator from '../../lib/containers/accumulators/check-suites-accumulator';
import PullRequestStatusContextView from '../../lib/views/pr-status-context-view';
import CheckSuiteView from '../../lib/views/check-suite-view';
import {pullRequestBuilder} from '../builder/graphql/pr';
import {commitBuilder, checkSuiteBuilder} from '../builder/graphql/timeline';

import pullRequestQuery from '../../lib/views/__generated__/prStatusesView_pullRequest.graphql';
import commitQuery from '../../lib/containers/accumulators/__generated__/checkSuitesAccumulator_commit.graphql';
import checkRunsQuery from '../../lib/containers/accumulators/__generated__/checkRunsAccumulator_checkSuite.graphql';

const NULL_CHECK_SUITE_RESULT = {
  errors: [],
  suites: [],
  runsBySuite: new Map(),
  loading: false,
};

describe('PrStatusesView', function() {
  function buildApp(override = {}) {
    const props = {
      relay: {
        refetch: () => {},
      },
      displayType: 'full',
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),
      ...override,
    };

    return <BarePrStatusesView {...props} />;
  }

  function nullStatus(conn) {
    conn.addEdge(e => e.node(n => n.commit(c => c.nullStatus())));
  }

  function setStatus(conn, fn) {
    conn.addEdge(e => e.node(n => n.commit(c => {
      c.status(fn);
    })));
  }

  it('renders nothing if the pull request has no status or checks', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .recentCommits(nullStatus)
      .build();

    const wrapper = shallow(buildApp({pullRequest}))
      .find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);

    assert.isTrue(wrapper.isEmptyRender());
  });

  it('logs errors to the console', function() {
    sinon.stub(console, 'error');

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .recentCommits(nullStatus)
      .build();
    const wrapper = shallow(buildApp({pullRequest, displayType: 'check'}));

    const e0 = new Error('oh no');
    const e1 = new Error('boom');
    wrapper.find(CheckSuitesAccumulator).renderProp('children')({
      errors: [e0, e1],
      suites: [],
      runsBySuite: new Map(),
      loading: false,
    });

    // eslint-disable-next-line no-console
    assert.isTrue(console.error.calledWith(e0));

    // eslint-disable-next-line no-console
    assert.isTrue(console.error.calledWith(e1));
  });

  describe('with displayType: check', function() {
    it('renders a commit status result', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(conn => setStatus(conn, s => s.state('PENDING')))
        .build();

      const wrapper = shallow(buildApp({pullRequest, displayType: 'check'}));
      const child0 = wrapper.find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);

      assert.isTrue(child0.find('Octicon[icon="primitive-dot"]').hasClass('github-PrStatuses--pending'));

      wrapper.setProps({
        pullRequest: pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => s.state('SUCCESS')))
          .build(),
      });
      const child1 = wrapper.find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);
      assert.isTrue(child1.find('Octicon[icon="check"]').hasClass('github-PrStatuses--success'));

      wrapper.setProps({
        pullRequest: pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => s.state('ERROR')))
          .build(),
      });
      const child2 = wrapper.find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);
      assert.isTrue(child2.find('Octicon[icon="alert"]').hasClass('github-PrStatuses--failure'));

      wrapper.setProps({
        pullRequest: pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => s.state('FAILURE')))
          .build(),
      });
      const child3 = wrapper.find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);
      assert.isTrue(child3.find('Octicon[icon="x"]').hasClass('github-PrStatuses--failure'));
    });

    it('renders a combined check suite result', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(nullStatus)
        .build();
      const wrapper = shallow(buildApp({pullRequest, displayType: 'check'}));

      const commit0 = commitBuilder(commitQuery)
        .checkSuites(conn => {
          conn.addEdge();
          conn.addEdge();
        })
        .build();
      const suite00 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const suite01 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const suites0 = commit0.checkSuites.edges.map(e => e.node);
      const child0 = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
        errors: [],
        suites: suites0,
        runsBySuite: new Map([
          [suites0[0], suite00.checkRuns.edges.map(e => e.node)],
          [suites0[1], suite01.checkRuns.edges.map(e => e.node)],
        ]),
        loading: false,
      });

      assert.isTrue(child0.find('Octicon[icon="primitive-dot"]').hasClass('github-PrStatuses--pending'));

      const commit1 = commitBuilder(commitQuery)
        .checkSuites(conn => {
          conn.addEdge();
          conn.addEdge();
        })
        .build();
      const suite10 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const suite11 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const suites1 = commit1.checkSuites.edges.map(e => e.node);
      const child1 = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
        errors: [],
        suites: suites1,
        runsBySuite: new Map([
          [suites1[0], suite10.checkRuns.edges.map(e => e.node)],
          [suites1[1], suite11.checkRuns.edges.map(e => e.node)],
        ]),
        loading: false,
      });

      assert.isTrue(child1.find('Octicon[icon="x"]').hasClass('github-PrStatuses--failure'));
    });

    it('combines a commit status and check suite results', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(conn => setStatus(conn, s => s.state('FAILURE')))
        .build();
      const wrapper = shallow(buildApp({pullRequest, displayType: 'check'}));

      const commit0 = commitBuilder(commitQuery)
        .checkSuites(conn => {
          conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const child0 = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
        errors: [],
        suites: commit0.checkSuites.edges.map(e => e.node),
        runsBySuite: new Map(),
        loading: false,
      });

      assert.isTrue(child0.find('Octicon[icon="x"]').hasClass('github-PrStatuses--failure'));
    });
  });

  describe('with displayType: full', function() {
    it('renders a donut chart', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(conn => setStatus(conn, s => {
          // Rollup status is *not* counted
          s.state('ERROR');
          s.addContext(c => c.state('SUCCESS'));
          s.addContext(c => c.state('SUCCESS'));
          s.addContext(c => c.state('FAILURE'));
          s.addContext(c => c.state('ERROR'));
          s.addContext(c => c.state('ERROR'));
          s.addContext(c => c.state('PENDING'));
        }))
        .build();

      const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

      const commit0 = commitBuilder(commitQuery)
        .checkSuites(conn => {
          // Suite-level rollup statuses are *not* counted
          conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('FAILURE')));
        })
        .build();
      const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
        })
        .build();
      const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          conn.addEdge(e => e.node(r => r.status('REQUESTED')));
        })
        .build();

      const suites = commit0.checkSuites.edges.map(e => e.node);
      const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
        errors: [],
        suites,
        runsBySuite: new Map([
          [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
          [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
        ]),
        loading: false,
      });

      const donutChart = child.find('StatusDonutChart');
      assert.strictEqual(donutChart.prop('pending'), 3);
      assert.strictEqual(donutChart.prop('failure'), 4);
      assert.strictEqual(donutChart.prop('success'), 5);
    });

    describe('the summary sentence', function() {
      it('reports when all checks are successes', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('SUCCESS');
            s.addContext(c => c.state('SUCCESS'));
            s.addContext(c => c.state('SUCCESS'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(child.find('.github-PrStatuses-summary').text(), 'All checks succeeded');
      });

      it('reports when all checks have failed', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('ERROR');
            s.addContext(c => c.state('FAILURE'));
            s.addContext(c => c.state('ERROR'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('TIMED_OUT')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('FAILURE')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('TIMED_OUT')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('TIMED_OUT')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('CANCELLED')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(child.find('.github-PrStatuses-summary').text(), 'All checks failed');
      });

      it('reports counts of mixed results, with proper pluralization', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            // Context summaries are not counted in the sentence
            s.state('ERROR');
            s.addContext(c => c.state('PENDING'));
            s.addContext(c => c.state('FAILURE'));
            s.addContext(c => c.state('SUCCESS'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            // Suite summaries are not counted in the sentence
            conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('ERROR')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('CANCELLED')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('ACTION_REQUIRED')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(
          child.find('.github-PrStatuses-summary').text(),
          '2 pending, 4 failing, and 3 successful checks',
        );
      });

      it('omits missing "pending" category', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            // Context summaries are not counted in the sentence
            s.state('PENDING');
            s.addContext(c => c.state('FAILURE'));
            s.addContext(c => c.state('SUCCESS'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            // Suite summaries are not counted in the sentence
            conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('CANCELLED')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('ACTION_REQUIRED')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(
          child.find('.github-PrStatuses-summary').text(),
          '4 failing and 3 successful checks',
        );
      });

      it('omits missing "failing" category', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            // Context summaries are not counted in the sentence
            s.state('ERROR');
            s.addContext(c => c.state('PENDING'));
            s.addContext(c => c.state('SUCCESS'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            // Suite summaries are not counted in the sentence
            conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('ERROR')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(
          child.find('.github-PrStatuses-summary').text(),
          '2 pending and 4 successful checks',
        );
      });

      it('omits missing "successful" category', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            // Context summaries are not counted in the sentence
            s.state('ERROR');
            s.addContext(c => c.state('PENDING'));
            s.addContext(c => c.state('FAILURE'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            // Suite summaries are not counted in the sentence
            conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();
        const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('FAILURE')));
          })
          .build();
        const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
          .checkRuns(conn => {
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('CANCELLED')));
            conn.addEdge(e => e.node(r => r.status('COMPLETED').conclusion('ACTION_REQUIRED')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], checkSuite0.checkRuns.edges.map(e => e.node)],
            [suites[1], checkSuite1.checkRuns.edges.map(e => e.node)],
          ]),
          loading: false,
        });

        assert.strictEqual(
          child.find('.github-PrStatuses-summary').text(),
          '2 pending and 4 failing checks',
        );
      });

      it('uses a singular noun for a single check', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            // Context summaries are not counted in the sentence
            s.state('ERROR');
            s.addContext(c => c.state('PENDING'));
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));
        const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites: [],
          runsBySuite: new Map(),
          loading: false,
        });

        assert.strictEqual(child.find('.github-PrStatuses-summary').text(), '1 pending check');
      });
    });

    it('renders a context view for each status context', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(conn => setStatus(conn, s => {
          s.addContext();
          s.addContext();
          s.addContext();
        }))
        .build();
      const [contexts] = pullRequest.recentCommits.edges.map(e => e.node.commit.status.contexts);

      const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));
      const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')(NULL_CHECK_SUITE_RESULT);

      const contextViews = child.find(PullRequestStatusContextView);
      assert.deepEqual(contextViews.map(v => v.prop('context')), contexts);
    });

    it('renders a check suite view for each check suite', function() {
      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .recentCommits(nullStatus)
        .build();
      const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));

      const commit0 = commitBuilder(commitQuery)
        .checkSuites(conn => {
          conn.addEdge();
          conn.addEdge();
        })
        .build();
      const suites = commit0.checkSuites.edges.map(e => e.node);
      const checkSuite0 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge();
          conn.addEdge();
          conn.addEdge();
        })
        .build();
      const checkSuite1 = checkSuiteBuilder(checkRunsQuery)
        .checkRuns(conn => {
          conn.addEdge();
          conn.addEdge();
          conn.addEdge();
        })
        .build();
      const checkRuns0 = checkSuite0.checkRuns.edges.map(e => e.node);
      const checkRuns1 = checkSuite1.checkRuns.edges.map(e => e.node);
      const runsBySuite = new Map([
        [suites[0], checkRuns0],
        [suites[1], checkRuns1],
      ]);

      const child = wrapper.find(CheckSuitesAccumulator).renderProp('children')({
        errors: [],
        suites,
        runsBySuite,
        loading: false,
      });

      const suiteViews = child.find(CheckSuiteView);
      assert.lengthOf(suiteViews, 2);
      assert.strictEqual(suiteViews.at(0).prop('checkSuite'), suites[0]);
      assert.strictEqual(suiteViews.at(0).prop('checkRuns'), checkRuns0);
      assert.strictEqual(suiteViews.at(1).prop('checkSuite'), suites[1]);
      assert.strictEqual(suiteViews.at(1).prop('checkRuns'), checkRuns1);
    });

    describe('the PeriodicRefresher to update status checks', function() {
      it('refetches with the current pull request ID', function() {
        const refetch = sinon.stub().callsArg(2);
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .id('pr0')
          .recentCommits(conn => setStatus(conn))
          .build();

        const wrapper = shallow(buildApp({pullRequest, relay: {refetch}}));
        const {refresher} = wrapper.instance();

        const didRefetch = sinon.spy();
        wrapper.find(CheckSuitesAccumulator).prop('onDidRefetch')(didRefetch);

        refresher.refreshNow();

        assert.isTrue(refetch.calledWith({id: 'pr0'}, null, sinon.match.func, {force: true}));
        assert.isTrue(didRefetch.called);
      });

      it('is configured with a short interval when all checks are pending', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('PENDING');
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));
        const {refresher} = wrapper.instance();
        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.PENDING_REFRESH_TIMEOUT);
      });

      it('is configured with a longer interval once all checks are completed', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('FAILURE');
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));
        const {refresher} = wrapper.instance();
        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.COMPLETED_REFRESH_TIMEOUT);
      });

      it('changes its interval as check suite and run results arrive', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('SUCCESS');
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest, displayType: 'full'}));
        const {refresher} = wrapper.instance();
        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.COMPLETED_REFRESH_TIMEOUT);

        const commit0 = commitBuilder(commitQuery)
          .checkSuites(conn => {
            conn.addEdge(e => e.node(s => s.status('IN_PROGRESS')));
            conn.addEdge(e => e.node(s => s.status('COMPLETED').conclusion('SUCCESS')));
          })
          .build();

        const suites = commit0.checkSuites.edges.map(e => e.node);
        wrapper.find(CheckSuitesAccumulator).renderProp('children')({
          errors: [],
          suites,
          runsBySuite: new Map([
            [suites[0], []],
            [suites[1], []],
          ]),
          loading: false,
        });
        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.PENDING_REFRESH_TIMEOUT);
      });

      it('changes its interval when the component is re-rendered', function() {
        const pullRequest0 = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('PENDING');
          }))
          .build();

        const wrapper = shallow(buildApp({pullRequest: pullRequest0, displayType: 'full'}));
        const {refresher} = wrapper.instance();
        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.PENDING_REFRESH_TIMEOUT);

        const pullRequest1 = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn, s => {
            s.state('SUCCESS');
            s.addContext(c => c.state('SUCCESS'));
            s.addContext(c => c.state('SUCCESS'));
          }))
          .build();
        wrapper.setProps({pullRequest: pullRequest1});

        assert.strictEqual(refresher.options.interval(), BarePrStatusesView.COMPLETED_REFRESH_TIMEOUT);
      });

      it('destroys the refresher on unmount', function() {
        const pullRequest = pullRequestBuilder(pullRequestQuery)
          .recentCommits(conn => setStatus(conn))
          .build();

        const wrapper = shallow(buildApp({pullRequest}));
        const {refresher} = wrapper.instance();

        sinon.spy(refresher, 'destroy');

        wrapper.unmount();
        assert.isTrue(refresher.destroy.called);
      });
    });
  });
});
