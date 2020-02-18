import React from 'react';
import {shallow} from 'enzyme';
import CommentGutterDecorationController from '../../lib/controllers/comment-gutter-decoration-controller';
import {getEndpoint} from '../../lib/models/endpoint';
import {Range} from 'atom';
import * as reporterProxy from '../../lib/reporter-proxy';
import ReviewsItem from '../../lib/items/reviews-item';

describe('CommentGutterDecorationController', function() {
  let atomEnv, workspace, editor;

  function buildApp(opts = {}) {
    const props = {
      workspace,
      editor,
      commentRow: 420,
      threadId: 'my-thread-will-go-on',
      extraClasses: ['celine', 'dion'],
      endpoint: getEndpoint('github.com'),
      owner: 'owner',
      repo: 'repo',
      number: 1337,
      workdir: 'dir/path',
      parent: 'TheThingThatMadeChildren',
      ...opts,
    };
    return <CommentGutterDecorationController {...props} />;
  }

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    editor = await workspace.open(__filename);
  });

  afterEach(function() {
    atomEnv.destroy();
  });


  it('decorates the comment gutter', function() {
    const wrapper = shallow(buildApp());
    editor.addGutter({name: 'github-comment-icon'});
    const marker = wrapper.find('Marker');
    const decoration = marker.find('Decoration');

    assert.deepEqual(marker.prop('bufferRange'), new Range([420, 0], [420, Infinity]));
    assert.isTrue(decoration.hasClass('celine'));
    assert.isTrue(decoration.hasClass('dion'));
    assert.isTrue(decoration.hasClass('github-editorCommentGutterIcon'));
    assert.strictEqual(decoration.children('button.icon.icon-comment').length, 1);

  });

  it('opens review dock and jumps to thread when clicked', async function() {
    sinon.stub(reporterProxy, 'addEvent');
    const jumpToThread = sinon.spy();
    sinon.stub(atomEnv.workspace, 'open').resolves({jumpToThread});
    const wrapper = shallow(buildApp());

    wrapper.find('button.icon-comment').simulate('click');
    assert.isTrue(atomEnv.workspace.open.calledWith(
      ReviewsItem.buildURI({host: 'github.com', owner: 'owner', repo: 'repo', number: 1337, workdir: 'dir/path'}),
      {searchAllPanes: true},
    ));
    await assert.async.isTrue(jumpToThread.calledWith('my-thread-will-go-on'));
    assert.isTrue(reporterProxy.addEvent.calledWith('open-review-thread', {
      package: 'github',
      from: 'TheThingThatMadeChildren',
    }));
  });
});
