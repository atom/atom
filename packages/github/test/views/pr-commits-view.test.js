import React from 'react';
import {shallow} from 'enzyme';

import PrCommitView from '../../lib/views/pr-commit-view';
import {PrCommitsView} from '../../lib/views/pr-commits-view';

const commitSpec = {
  committer: {
    avatarUrl: 'https://avatars3.githubusercontent.com/u/3781742',
    name: 'Margaret Hamilton',
    date: '2018-05-16T21:54:24.500Z',
  },
  messageHeadline: 'This one weird trick for getting to the moon will blow your mind 🚀',
  shortSha: 'bad1dea',
  sha: 'bad1deaea3d816383721478fc631b5edd0c2b370',
  url: 'https://github.com/atom/github/pull/1684/commits/bad1deaea3d816383721478fc631b5edd0c2b370',
};

describe('PrCommitsView', function() {
  function buildApp(opts, overloadProps = {}) {
    const o = {
      relayHasMore: () => false,
      relayLoadMore: () => {},
      relayIsLoading: () => false,
      commitSpecs: [],
      commitStartCursor: 0,
      ...opts,
    };

    if (o.commitTotal === undefined) {
      o.commitTotal = o.commitSpecs.length;
    }

    const props = {
      relay: {
        hasMore: o.relayHasMore,
        loadMore: o.relayLoadMore,
        isLoading: o.relayIsLoading,
      },
      ...overloadProps,
    };

    const commits = {
      edges: o.commitSpecs.map((spec, i) => ({
        cursor: `result${i}`,
        node: {
          commit: spec,
          id: i,
        },
      })),
      pageInfo: {
        startCursor: `result${o.commitStartCursor}`,
        endCursor: `result${o.commitStartCursor + o.commitSpecs.length}`,
        hasNextPage: o.commitStartCursor + o.commitSpecs.length < o.commitTotal,
        hasPreviousPage: o.commitCursor !== 0,
      },
      totalCount: o.commitTotal,
    };
    props.pullRequest = {commits};

    return <PrCommitsView {...props} />;
  }

  it('renders commits', function() {
    const commitSpecs = [commitSpec, commitSpec];
    const wrapper = shallow(buildApp({commitSpecs}));
    assert.lengthOf(wrapper.find(PrCommitView), commitSpecs.length);
  });

  describe('load more button', function() {
    it('is not rendered if there are no more commits', function() {
      const commitSpecs = [commitSpec, commitSpec];
      const wrapper = shallow(buildApp({relayHasMore: () => false, commitSpecs}));
      assert.lengthOf(wrapper.find('.github-PrCommitsView-load-more-button'), 0);
    });

    it('is rendered if there are more commits', function() {
      const commitSpecs = [commitSpec, commitSpec];
      const wrapper = shallow(buildApp({relayHasMore: () => true, commitSpecs}));
      assert.lengthOf(wrapper.find('.github-PrCommitsView-load-more-button'), 1);
    });

    it('calls relay.loadMore when load more button is clicked', function() {
      const commitSpecs = [commitSpec, commitSpec];
      const loadMoreStub = sinon.stub(PrCommitsView.prototype, 'loadMore');
      const wrapper = shallow(buildApp({relayHasMore: () => true, commitSpecs}));
      assert.strictEqual(loadMoreStub.callCount, 0);
      wrapper.find('.github-PrCommitsView-load-more-button').simulate('click');
      assert.strictEqual(loadMoreStub.callCount, 1);
    });
  });
});
