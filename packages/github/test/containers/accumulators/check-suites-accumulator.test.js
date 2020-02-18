import React from 'react';
import {shallow} from 'enzyme';

import {BareCheckSuitesAccumulator} from '../../../lib/containers/accumulators/check-suites-accumulator';
import CheckRunsAccumulator from '../../../lib/containers/accumulators/check-runs-accumulator';
import {commitBuilder} from '../../builder/graphql/timeline';

import commitQuery from '../../../lib/containers/accumulators/__generated__/checkSuitesAccumulator_commit.graphql';

describe('CheckSuitesAccumulator', function() {
  function buildApp(override = {}) {
    const props = {
      relay: {
        hasMore: () => false,
        loadMore: () => {},
        isLoading: () => false,
      },
      commit: commitBuilder(commitQuery).build(),
      children: () => <div />,
      ...override,
    };

    return <BareCheckSuitesAccumulator {...props} />;
  }

  it('passes checkSuites as its result batch', function() {
    const commit = commitBuilder(commitQuery)
      .checkSuites(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();

    const wrapper = shallow(buildApp({commit}));

    assert.deepEqual(
      wrapper.find('Accumulator').prop('resultBatch'),
      commit.checkSuites.edges.map(e => e.node),
    );
  });

  it('handles an error from the check suite results', function() {
    const err = new Error('ouch');

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({children}))
      .find('Accumulator').renderProp('children')(err, [], false);

    assert.isTrue(wrapper.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [err],
      suites: [],
      runsBySuite: new Map(),
      loading: false,
    }));
  });

  it('recursively renders a CheckRunsAccumulator for each check suite', function() {
    const commit = commitBuilder(commitQuery)
      .checkSuites(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();
    const checkSuites = commit.checkSuites.edges.map(e => e.node);
    const children = sinon.stub().returns(<div className="bottom" />);

    const wrapper = shallow(buildApp({commit, children}));

    const args = [null, wrapper.find('Accumulator').prop('resultBatch'), false];
    const suiteWrapper = wrapper.find('Accumulator').renderProp('children')(...args);

    const accumulator0 = suiteWrapper.find(CheckRunsAccumulator);
    assert.strictEqual(accumulator0.prop('checkSuite'), checkSuites[0]);
    const runsWrapper0 = accumulator0.renderProp('children')({error: null, checkRuns: [1, 2, 3], loading: false});

    const accumulator1 = runsWrapper0.find(CheckRunsAccumulator);
    assert.strictEqual(accumulator1.prop('checkSuite'), checkSuites[1]);
    const runsWrapper1 = accumulator1.renderProp('children')({error: null, checkRuns: [4, 5, 6], loading: false});

    assert.isTrue(runsWrapper1.exists('.bottom'));
    assert.isTrue(children.calledWith({
      errors: [],
      suites: checkSuites,
      runsBySuite: new Map([
        [checkSuites[0], [1, 2, 3]],
        [checkSuites[1], [4, 5, 6]],
      ]),
      loading: false,
    }));
  });

  it('handles errors from each CheckRunsAccumulator', function() {
    const commit = commitBuilder(commitQuery)
      .checkSuites(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();
    const checkSuites = commit.checkSuites.edges.map(e => e.node);
    const children = sinon.stub().returns(<div className="bottom" />);

    const wrapper = shallow(buildApp({commit, children}));

    const args = [null, checkSuites, false];
    const suiteWrapper = wrapper.find('Accumulator').renderProp('children')(...args);

    const accumulator0 = suiteWrapper.find(CheckRunsAccumulator);
    const error0 = new Error('uh');
    const runsWrapper0 = accumulator0.renderProp('children')({error: error0, checkRuns: [], loading: false});

    const accumulator1 = runsWrapper0.find(CheckRunsAccumulator);
    const error1 = new Error('lp0 on fire');
    const runsWrapper1 = accumulator1.renderProp('children')({error: error1, checkRuns: [], loading: false});

    assert.isTrue(runsWrapper1.exists('.bottom'));
    assert.isTrue(children.calledWith({
      errors: [error0, error1],
      suites: checkSuites,
      runsBySuite: new Map([
        [checkSuites[0], []],
        [checkSuites[1], []],
      ]),
      loading: false,
    }));
  });
});
