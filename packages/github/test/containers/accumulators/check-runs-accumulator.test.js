import React from 'react';
import {shallow} from 'enzyme';

import {BareCheckRunsAccumulator} from '../../../lib/containers/accumulators/check-runs-accumulator';
import {checkSuiteBuilder} from '../../builder/graphql/timeline';

import checkSuiteQuery from '../../../lib/containers/accumulators/__generated__/checkRunsAccumulator_checkSuite.graphql';

describe('CheckRunsAccumulator', function() {
  function buildApp(override = {}) {
    const props = {
      relay: {
        hasMore: () => false,
        loadMore: () => {},
        isLoading: () => false,
      },
      checkSuite: checkSuiteBuilder(checkSuiteQuery).build(),
      children: () => <div />,
      onDidRefetch: () => {},
      ...override,
    };

    return <BareCheckRunsAccumulator {...props} />;
  }

  it('passes check runs as its result batch', function() {
    const checkSuite = checkSuiteBuilder(checkSuiteQuery)
      .checkRuns(conn => {
        conn.addEdge();
        conn.addEdge();
        conn.addEdge();
      })
      .build();

    const wrapper = shallow(buildApp({checkSuite}));

    assert.deepEqual(
      wrapper.find('Accumulator').prop('resultBatch'),
      checkSuite.checkRuns.edges.map(e => e.node),
    );
  });

  it('passes a child render prop', function() {
    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({children}));
    const resultWrapper = wrapper.find('Accumulator').renderProp('children')(null, [], false);

    assert.isTrue(resultWrapper.exists('.done'));
    assert.isTrue(children.calledWith({
      error: null,
      checkRuns: [],
      loading: false,
    }));
  });
});
