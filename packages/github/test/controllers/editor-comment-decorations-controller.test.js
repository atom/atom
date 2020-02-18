import React from 'react';
import {shallow} from 'enzyme';
import {Range} from 'atom';

import EditorCommentDecorationsController from '../../lib/controllers/editor-comment-decorations-controller';
import CommentGutterDecorationController from '../../lib/controllers/comment-gutter-decoration-controller';
import Marker from '../../lib/atom/marker';
import Decoration from '../../lib/atom/decoration';
import {getEndpoint} from '../../lib/models/endpoint';
import ReviewsItem from '../../lib/items/reviews-item';

describe('EditorCommentDecorationsController', function() {
  let atomEnv, workspace, editor, wrapper;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    editor = await workspace.open(__filename);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(opts = {}) {
    const props = {
      endpoint: getEndpoint('github.com'),
      owner: 'owner',
      repo: 'repo',
      number: 123,
      workdir: __dirname,

      workspace,
      editor,
      threadsForPath: [],
      commentTranslationsForPath: {
        diffToFilePosition: new Map(),
        removed: false,
      },

      ...opts,
    };

    return <EditorCommentDecorationsController {...props} />;
  }

  it('renders nothing if no position translations are available for this path', function() {
    wrapper = shallow(buildApp({commentTranslationsForPath: null}));
    assert.isTrue(wrapper.isEmptyRender());
  });

  it('creates a marker and decoration controller for each comment thread at its translated line position', function() {
    const threadsForPath = [
      {rootCommentID: 'comment0', position: 4, threadID: 'thread0'},
      {rootCommentID: 'comment1', position: 10, threadID: 'thread1'},
      {rootCommentID: 'untranslateable', position: 20, threadID: 'thread2'},
      {rootCommentID: 'positionless', position: null, threadID: 'thread3'},
    ];

    const commentTranslationsForPath = {
      diffToFilePosition: new Map([
        [4, 7],
        [10, 13],
      ]),
      removed: false,
    };

    wrapper = shallow(buildApp({threadsForPath, commentTranslationsForPath}));

    const markers = wrapper.find(Marker);
    assert.lengthOf(markers, 2);
    assert.isTrue(markers.someWhere(w => w.prop('bufferRange').isEqual([[6, 0], [6, Infinity]])));
    assert.isTrue(markers.someWhere(w => w.prop('bufferRange').isEqual([[12, 0], [12, Infinity]])));

    const controllers = wrapper.find(CommentGutterDecorationController);
    assert.lengthOf(controllers, 2);
    assert.isTrue(controllers.someWhere(w => w.prop('commentRow') === 6));
    assert.isTrue(controllers.someWhere(w => w.prop('commentRow') === 12));
  });

  it('creates a line decoration for each line with a comment', function() {
    const threadsForPath = [
      {rootCommentID: 'comment0', position: 4, threadID: 'thread0'},
      {rootCommentID: 'comment1', position: 10, threadID: 'thread1'},
    ];
    const commentTranslationsForPath = {
      diffToFilePosition: new Map([
        [4, 5],
        [10, 11],
      ]),
      removed: false,
    };

    wrapper = shallow(buildApp({threadsForPath, commentTranslationsForPath}));

    const decorations = wrapper.find(Decoration);
    assert.lengthOf(decorations.findWhere(decoration => decoration.prop('type') === 'line'), 2);
  });

  it('updates rendered marker positions as the underlying buffer is modified', function() {
    const threadsForPath = [
      {rootCommentID: 'comment0', position: 4, threadID: 'thread0'},
    ];

    const commentTranslationsForPath = {
      diffToFilePosition: new Map([[4, 4]]),
      removed: false,
      digest: '1111',
    };

    wrapper = shallow(buildApp({threadsForPath, commentTranslationsForPath}));

    const marker = wrapper.find(Marker);
    assert.isTrue(marker.prop('bufferRange').isEqual([[3, 0], [3, Infinity]]));

    marker.prop('didChange')({newRange: Range.fromObject([[5, 0], [5, 3]])});

    // Ensure the component re-renders
    wrapper.setProps({
      commentTranslationsForPath: {
        ...commentTranslationsForPath,
        digest: '2222',
      },
    });

    assert.isTrue(wrapper.find(Marker).prop('bufferRange').isEqual([[5, 0], [5, 3]]));
  });

  it('creates a block decoration if the diff was too large to parse', async function() {
    const threadsForPath = [
      {rootCommentID: 'comment0', position: 4, threadID: 'thread0'},
      {rootCommentID: 'comment1', position: 10, threadID: 'thread1'},
    ];
    const commentTranslationsForPath = {
      diffToFilePosition: new Map(),
      removed: true,
    };

    wrapper = shallow(buildApp({
      threadsForPath,
      commentTranslationsForPath,
      endpoint: getEndpoint('github.enterprise.horse'),
      owner: 'some-owner',
      repo: 'a-repo',
      number: 400,
      workdir: __dirname,
    }));

    const decorations = wrapper.find(Decoration);
    assert.lengthOf(decorations.findWhere(decoration => decoration.prop('type') === 'line'), 0);
    assert.lengthOf(decorations.findWhere(decoration => decoration.prop('type') === 'block'), 1);

    const reviewsItem = {jumpToThread: sinon.spy()};
    sinon.stub(workspace, 'open').resolves(reviewsItem);

    await wrapper.find('button').prop('onClick')();
    assert.isTrue(workspace.open.calledWith(
      ReviewsItem.buildURI({
        host: 'github.enterprise.horse',
        owner: 'some-owner',
        repo: 'a-repo',
        number: 400,
        workdir: __dirname,
      }),
      {searchAllPanes: true},
    ));
    assert.isTrue(reviewsItem.jumpToThread.calledWith('thread0'));
  });
});
