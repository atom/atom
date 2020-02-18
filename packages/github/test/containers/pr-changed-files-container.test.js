import React from 'react';
import {shallow} from 'enzyme';

import {getEndpoint} from '../../lib/models/endpoint';
import {multiFilePatchBuilder} from '../builder/patch';

import PullRequestChangedFilesContainer from '../../lib/containers/pr-changed-files-container';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';

describe('PullRequestChangedFilesContainer', function() {
  function buildApp(overrideProps = {}) {
    return (
      <PullRequestChangedFilesContainer
        owner="atom"
        repo="github"
        number={1804}
        token="1234"
        endpoint={getEndpoint('github.com')}
        itemType={IssueishDetailItem}
        destroy={() => {}}
        shouldRefetch={false}
        workspace={{}}
        commands={{}}
        keymaps={{}}
        tooltips={{}}
        config={{}}
        localRepository={{}}
        reviewCommentsLoading={false}
        reviewCommentThreads={[]}
        onOpenFilesTab={() => {}}
        {...overrideProps}
      />
    );
  }

  describe('when the patch is loading', function() {
    it('renders a LoadingView', function() {
      const wrapper = shallow(buildApp());
      const subwrapper = wrapper.find('PullRequestPatchContainer').renderProp('children')(null, null);
      assert.isTrue(subwrapper.exists('LoadingView'));
    });
  });

  describe('when the patch is fetched successfully', function() {
    it('passes the MultiFilePatch to a MultiFilePatchController', function() {
      const {multiFilePatch} = multiFilePatchBuilder().build();

      const wrapper = shallow(buildApp());
      const subwrapper = wrapper.find('PullRequestPatchContainer').renderProp('children')(null, multiFilePatch);

      assert.strictEqual(subwrapper.find('MultiFilePatchController').prop('multiFilePatch'), multiFilePatch);
    });

    it('passes extra props through to MultiFilePatchController', function() {
      const {multiFilePatch} = multiFilePatchBuilder().build();
      const extraProp = Symbol('really really extra');

      const wrapper = shallow(buildApp({extraProp}));
      const subwrapper = wrapper.find('PullRequestPatchContainer').renderProp('children')(null, multiFilePatch);

      assert.strictEqual(subwrapper.find('MultiFilePatchController').prop('extraProp'), extraProp);
    });

    it('re-fetches data when shouldRefetch is true', function() {
      const wrapper = shallow(buildApp({shouldRefetch: true}));
      assert.isTrue(wrapper.find('PullRequestPatchContainer').prop('refetch'));
    });

    it('manages a subscription on the active MultiFilePatch', function() {
      const {multiFilePatch: mfp0} = multiFilePatchBuilder().addFilePatch().build();

      const wrapper = shallow(buildApp());
      wrapper.find('PullRequestPatchContainer').renderProp('children')(null, mfp0);

      assert.strictEqual(mfp0.getFilePatches()[0].emitter.listenerCountForEventName('change-render-status'), 1);

      wrapper.find('PullRequestPatchContainer').renderProp('children')(null, mfp0);
      assert.strictEqual(mfp0.getFilePatches()[0].emitter.listenerCountForEventName('change-render-status'), 1);

      const {multiFilePatch: mfp1} = multiFilePatchBuilder().addFilePatch().build();
      wrapper.find('PullRequestPatchContainer').renderProp('children')(null, mfp1);

      assert.strictEqual(mfp0.getFilePatches()[0].emitter.listenerCountForEventName('change-render-status'), 0);
      assert.strictEqual(mfp1.getFilePatches()[0].emitter.listenerCountForEventName('change-render-status'), 1);
    });

    it('disposes the MultiFilePatch subscription on unmount', function() {
      const {multiFilePatch} = multiFilePatchBuilder().addFilePatch().build();

      const wrapper = shallow(buildApp());
      const subwrapper = wrapper.find('PullRequestPatchContainer').renderProp('children')(null, multiFilePatch);

      const mfp = subwrapper.find('MultiFilePatchController').prop('multiFilePatch');
      const [fp] = mfp.getFilePatches();
      assert.strictEqual(fp.emitter.listenerCountForEventName('change-render-status'), 1);

      wrapper.unmount();
      assert.strictEqual(fp.emitter.listenerCountForEventName('change-render-status'), 0);
    });
  });

  describe('when the patch load fails', function() {
    it('renders the message in an ErrorView', function() {
      const error = 'oh noooooo';

      const wrapper = shallow(buildApp());
      const subwrapper = wrapper.find('PullRequestPatchContainer').renderProp('children')(error, null);

      assert.deepEqual(subwrapper.find('ErrorView').prop('descriptions'), [error]);
    });
  });
});
