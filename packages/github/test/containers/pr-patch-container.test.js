import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import PullRequestPatchContainer from '../../lib/containers/pr-patch-container';
import {rawDiff, rawDiffWithPathPrefix, rawAdditionDiff, rawDeletionDiff} from '../fixtures/diffs/raw-diff';
import {getEndpoint} from '../../lib/models/endpoint';

describe('PullRequestPatchContainer', function() {
  function buildApp(override = {}) {
    const props = {
      owner: 'atom',
      repo: 'github',
      number: 1995,
      endpoint: getEndpoint('github.com'),
      token: '1234',
      refetch: false,
      children: () => null,
      ...override,
    };

    return <PullRequestPatchContainer {...props} />;
  }

  function setDiffResponse(body, options) {
    const opts = {
      status: 200,
      statusText: 'OK',
      getResolver: cb => cb(),
      etag: null,
      callNum: null,
      ...options,
    };

    let stub = window.fetch;
    if (!stub.restore) {
      stub = sinon.stub(window, 'fetch');
    }

    let call = stub;
    if (opts.callNum !== null) {
      call = stub.onCall(opts.callNum);
    }

    call.callsFake(() => {
      const headers = {
        'Content-type': 'text/plain',
      };
      if (opts.etag !== null) {
        headers.ETag = opts.etag;
      }

      const resp = new window.Response(body, {
        status: opts.status,
        statusText: opts.statusText,
        headers,
      });

      let resolveResponsePromise = null;
      const promise = new Promise(resolve => {
        resolveResponsePromise = resolve;
      });
      opts.getResolver(() => resolveResponsePromise(resp));
      return promise;
    });
    return stub;
  }

  function createChildrenCallback() {
    const calls = [];
    const waitingCallbacks = [];

    const fn = function(error, mfp) {
      if (waitingCallbacks.length > 0) {
        waitingCallbacks.shift()({error, mfp});
        return null;
      }

      calls.push({error, mfp});
      return null;
    };

    fn.nextCall = function() {
      if (calls.length > 0) {
        return Promise.resolve(calls.shift());
      }

      return new Promise(resolve => waitingCallbacks.push(resolve));
    };

    return fn;
  }

  describe('while the patch is loading', function() {
    it('renders its child prop with nulls', async function() {
      setDiffResponse(rawDiff);

      const children = createChildrenCallback();
      shallow(buildApp({children}));
      assert.deepEqual(await children.nextCall(), {error: null, mfp: null});
    });
  });

  describe('when the patch has been fetched successfully', function() {
    it('builds the correct request', async function() {
      const stub = setDiffResponse(rawDiff);
      const children = createChildrenCallback();
      shallow(buildApp({
        owner: 'smashwilson',
        repo: 'pushbot',
        number: 12,
        endpoint: getEndpoint('github.com'),
        token: 'swordfish',
        children,
      }));

      assert.isTrue(stub.calledWith(
        'https://api.github.com/repos/smashwilson/pushbot/pulls/12',
        {
          headers: {
            Accept: 'application/vnd.github.v3.diff',
            Authorization: 'bearer swordfish',
          },
        },
      ));

      assert.deepEqual(await children.nextCall(), {error: null, mfp: null});

      const {error, mfp} = await children.nextCall();
      assert.isNull(error);

      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.strictEqual(fp.getOldFile().getPath(), 'file.txt');
      assert.strictEqual(fp.getNewFile().getPath(), 'file.txt');
      assert.lengthOf(fp.getHunks(), 1);
      const [h] = fp.getHunks();
      assert.strictEqual(h.getSectionHeading(), 'class Thing {');
    });

    it('modifies the patch to exclude a/ and b/ prefixes on file paths', async function() {
      setDiffResponse(rawDiffWithPathPrefix);

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.isNull(error);
      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.notMatch(fp.getOldFile().getPath(), /^[a|b]\//);
      assert.notMatch(fp.getNewFile().getPath(), /^[a|b]\//);
    });

    it('excludes a/ prefix on the old file of a deletion', async function() {
      setDiffResponse(rawDeletionDiff);

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.isNull(error);
      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.strictEqual(fp.getOldFile().getPath(), 'deleted');
      assert.isFalse(fp.getNewFile().isPresent());
    });

    it('excludes b/ prefix on the new file of an addition', async function() {
      setDiffResponse(rawAdditionDiff);

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.isNull(error);
      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.isFalse(fp.getOldFile().isPresent());
      assert.strictEqual(fp.getNewFile().getPath(), 'added');
    });

    it('converts file paths to use native path separators', async function() {
      setDiffResponse(rawDiffWithPathPrefix);
      const children = createChildrenCallback();

      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.isNull(error);
      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.strictEqual(fp.getNewFile().getPath(), path.join('bad/path.txt'));
      assert.strictEqual(fp.getOldFile().getPath(), path.join('bad/path.txt'));
    });

    it('does not setState if the component has been unmounted', async function() {
      let resolve = null;
      setDiffResponse(rawDiff, {
        getResolver(cb) { resolve = cb; },
      });
      const children = createChildrenCallback();
      const wrapper = shallow(buildApp({children}));
      const fetchDiffSpy = sinon.spy(wrapper.instance(), 'fetchDiff');
      wrapper.setProps({refetch: true});

      const setStateSpy = sinon.spy(wrapper.instance(), 'setState');
      wrapper.unmount();

      resolve();
      await fetchDiffSpy.lastCall.returnValue;

      assert.isFalse(setStateSpy.called);
    });

    it('respects a custom largeDiffThreshold', async function() {
      setDiffResponse(rawDiff);

      const children = createChildrenCallback();
      shallow(buildApp({
        largeDiffThreshold: 1,
        children,
      }));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.isNull(error);
      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();
      assert.isFalse(fp.getRenderStatus().isVisible());
    });
  });

  describe('when there has been an error', function() {
    it('reports an error when the network request fails', async function() {
      const output = sinon.stub(console, 'error');
      sinon.stub(window, 'fetch').rejects(new Error('kerPOW'));

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.strictEqual(error, 'Network error encountered fetching the patch: kerPOW.');
      assert.isNull(mfp);
      assert.isTrue(output.called);
    });

    it('reports an error if the fetch returns a non-OK response', async function() {
      setDiffResponse('ouch', {
        status: 404,
        statusText: 'Not found',
      });

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.strictEqual(error, 'Unable to fetch the diff for this pull request: Not found.');
      assert.isNull(mfp);
    });

    it('reports an error if the patch cannot be parsed', async function() {
      const output = sinon.stub(console, 'error');
      setDiffResponse('bad diff no treat for you');

      const children = createChildrenCallback();
      shallow(buildApp({children}));

      await children.nextCall();
      const {error, mfp} = await children.nextCall();

      assert.strictEqual(error, 'Unable to parse the diff for this pull request.');
      assert.isNull(mfp);
      assert.isTrue(output.called);
    });
  });

  describe('when a refetch is requested', function() {
    it('refetches patch data on the next render', async function() {
      const fetch = setDiffResponse(rawDiff);

      const children = createChildrenCallback();
      const wrapper = shallow(buildApp({children}));
      assert.strictEqual(fetch.callCount, 1);
      assert.deepEqual(await children.nextCall(), {error: null, mfp: null});
      await children.nextCall();

      wrapper.setProps({refetch: true});
      assert.strictEqual(fetch.callCount, 2);
    });

    it('does not refetch data on additional renders', async function() {
      const fetch = setDiffResponse(rawDiff);

      const children = createChildrenCallback();
      const wrapper = shallow(buildApp({children, refetch: true}));
      assert.strictEqual(fetch.callCount, 1);

      await children.nextCall();
      await children.nextCall();

      wrapper.setProps({refetch: true});
      assert.strictEqual(fetch.callCount, 1);
    });

    it('does not reparse data if the diff has not been modified', async function() {
      const stub = setDiffResponse(rawDiff, {callNum: 0, etag: '12345'});
      setDiffResponse(null, {callNum: 1, status: 304});

      const children = createChildrenCallback();
      const wrapper = shallow(buildApp({
        owner: 'smashwilson',
        repo: 'pushbot',
        number: 12,
        endpoint: getEndpoint('github.com'),
        token: 'swordfish',
        children,
      }));

      assert.deepEqual(await children.nextCall(), {error: null, mfp: null});
      const {error: error0, mfp: mfp0} = await children.nextCall();
      assert.isNull(error0);

      wrapper.setProps({refetch: true});

      assert.deepEqual(await children.nextCall(), {error: null, mfp: mfp0});
      assert.deepEqual(await children.nextCall(), {error: null, mfp: null});
      const {error: error1, mfp: mfp1} = await children.nextCall();
      assert.isNull(error1);
      assert.strictEqual(mfp1, mfp0);

      assert.isTrue(stub.calledWith(
        'https://api.github.com/repos/smashwilson/pushbot/pulls/12',
        {
          headers: {
            'Accept': 'application/vnd.github.v3.diff',
            'Authorization': 'bearer swordfish',
            'If-None-Match': '12345',
          },
        },
      ));
    });
  });
});
