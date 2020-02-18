import React from 'react';
import {shallow} from 'enzyme';
import {shell} from 'electron';

import ActionableReviewView from '../../lib/views/actionable-review-view';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('ActionableReviewView', function() {
  let atomEnv, mockEvent, mockMenu;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();

    mockEvent = {
      preventDefault: sinon.spy(),
    };

    mockMenu = {
      append: sinon.spy(),
      popup: sinon.spy(),
    };

    sinon.stub(reporterProxy, 'addEvent');
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      originalContent: {body: 'original'},
      isPosting: false,
      commands: atomEnv.commands,
      confirm: () => {},
      contentUpdater: () => {},
      render: () => <div />,
      createMenu: () => mockMenu,
      createMenuItem: opts => opts,
      ...override,
    };

    return <ActionableReviewView {...props} />;
  }

  describe('out of editing mode', function() {
    it('calls its render prop with a menu-creation function', function() {
      const render = sinon.stub().returns(<div className="done" />);
      const wrapper = shallow(buildApp({render}));

      assert.isTrue(wrapper.exists('.done'));

      const [showActionsMenu] = render.lastCall.args;
      showActionsMenu(mockEvent, {}, {});
      assert.isTrue(mockEvent.preventDefault.called);
      assert.isTrue(mockMenu.popup.called);
    });

    describe('the menu', function() {
      function triggerMenu(content, author) {
        const items = [];

        const wrapper = shallow(buildApp({
          createMenuItem: itemOpts => items.push(itemOpts),
          render: showActionsMenu => showActionsMenu(mockEvent, content, author),
        }));

        return {items, wrapper};
      }

      it("opens the content object's URL with 'Open on GitHub'", async function() {
        sinon.stub(shell, 'openExternal').callsArg(2);

        const item = triggerMenu({url: 'https://github.com'}, {}).items.find(i => i.label === 'Open on GitHub');
        await item.click();

        assert.isTrue(shell.openExternal.calledWith('https://github.com', {}));
        assert.isTrue(reporterProxy.addEvent.calledWith('open-comment-in-browser'));
      });

      it("rejects the promise when 'Open on GitHub' fails", async function() {
        sinon.stub(shell, 'openExternal').callsArgWith(2, new Error("I don't feel like it"));

        const item = triggerMenu({url: 'https://github.com'}, {}).items.find(i => i.label === 'Open on GitHub');
        await assert.isRejected(item.click());
        assert.isFalse(reporterProxy.addEvent.called);
      });

      it('opens a prepopulated abuse-reporting link with "Report abuse"', async function() {
        sinon.stub(shell, 'openExternal').callsArg(2);

        const item = triggerMenu({url: 'https://github.com/a/b'}, {login: 'tyrion'})
          .items.find(i => i.label === 'Report abuse');
        await item.click();

        assert.isTrue(shell.openExternal.calledWith(
          'https://github.com/contact/report-content?report=tyrion&content_url=https%3A%2F%2Fgithub.com%2Fa%2Fb',
          {},
        ));
        assert.isTrue(reporterProxy.addEvent.calledWith('report-abuse'));
      });

      it("rejects the promise when 'Report abuse' fails", async function() {
        sinon.stub(shell, 'openExternal').callsArgWith(2, new Error('nah'));

        const item = triggerMenu({url: 'https://github.com/a/b'}, {login: 'tyrion'})
          .items.find(i => i.label === 'Report abuse');
        await assert.isRejected(item.click());
        assert.isFalse(reporterProxy.addEvent.called);
      });

      it('includes an "edit" item only if the content is editable', function() {
        assert.isTrue(triggerMenu({viewerCanUpdate: true}, {}).items.some(item => item.label === 'Edit'));
        assert.isFalse(triggerMenu({viewerCanUpdate: false}, {}).items.some(item => item.label === 'Edit'));
      });

      it('enters the editing state if the "edit" item is chosen', function() {
        const {items, wrapper} = triggerMenu({viewerCanUpdate: true}, {});
        assert.isFalse(wrapper.exists('.github-Review-editable'));

        items.find(i => i.label === 'Edit').click();
        wrapper.update();
        assert.isTrue(wrapper.exists('.github-Review-editable'));
      });
    });
  });

  describe('in editing mode', function() {
    let mockEditor, mockEditorElement;

    beforeEach(function() {
      mockEditorElement = {focus: sinon.spy()};
      mockEditor = {getElement: () => mockEditorElement};
    });

    function shallowEditMode(override = {}) {
      let editCallback;
      const wrapper = shallow(buildApp({
        ...override,
        render: showActionsMenu => {
          showActionsMenu(mockEvent, {viewerCanUpdate: true}, {});
          if (override.render) {
            return override.render();
          } else {
            return <div />;
          }
        },
        createMenuItem: opts => {
          if (opts.label === 'Edit') {
            editCallback = opts.click;
          }
        },
      }));

      wrapper.instance().refEditor.setter(mockEditor);

      editCallback();
      return wrapper.update();
    }

    it('displays a focused editor prepopulated with the original content body and control buttons', function() {
      const wrapper = shallowEditMode({
        originalContent: {body: 'this is what it said before'},
      });

      const editor = wrapper.find('AtomTextEditor');
      assert.strictEqual(editor.prop('buffer').getText(), 'this is what it said before');
      assert.isFalse(editor.prop('readOnly'));

      assert.isTrue(mockEditorElement.focus.called);

      assert.isFalse(wrapper.find('.github-Review-editableCancelButton').prop('disabled'));
      assert.isFalse(wrapper.find('.github-Review-updateCommentButton').prop('disabled'));
    });

    it('does not repopulate the buffer when the edit state has not changed', function() {
      const wrapper = shallowEditMode({
        originalContent: {body: 'this is what it said before'},
      });

      assert.strictEqual(
        wrapper.find('AtomTextEditor').prop('buffer').getText(),
        'this is what it said before',
      );
      assert.strictEqual(mockEditorElement.focus.callCount, 1);

      wrapper.setProps({originalContent: {body: 'nope'}});

      assert.strictEqual(
        wrapper.find('AtomTextEditor').prop('buffer').getText(),
        'this is what it said before',
      );
      assert.strictEqual(mockEditorElement.focus.callCount, 1);
    });

    it('disables the editor and buttons while posting is in progress', function() {
      const wrapper = shallowEditMode({isPosting: true});

      assert.isTrue(wrapper.exists('.github-Review-editable--disabled'));
      assert.isTrue(wrapper.find('AtomTextEditor').prop('readOnly'));
      assert.isTrue(wrapper.find('.github-Review-editableCancelButton').prop('disabled'));
      assert.isTrue(wrapper.find('.github-Review-updateCommentButton').prop('disabled'));
    });

    describe('when the submit button is clicked', function() {
      it('does nothing and exits edit mode when the buffer is unchanged', async function() {
        const contentUpdater = sinon.stub().resolves();

        const wrapper = shallowEditMode({
          originalContent: {id: 'id-0', body: 'original'},
          contentUpdater,
          render: () => <div className="non-editable" />,
        });

        await wrapper.find('.github-Review-updateCommentButton').prop('onClick')();
        assert.isFalse(contentUpdater.called);
        assert.isTrue(wrapper.exists('.non-editable'));
      });

      it('does nothing and exits edit mode when the buffer is empty', async function() {
        const contentUpdater = sinon.stub().resolves();

        const wrapper = shallowEditMode({
          originalContent: {id: 'id-0', body: 'original'},
          contentUpdater,
          render: () => <div className="non-editable" />,
        });

        wrapper.find('AtomTextEditor').prop('buffer').setText('');
        await wrapper.find('.github-Review-updateCommentButton').prop('onClick')();
        assert.isFalse(contentUpdater.called);
        assert.isTrue(wrapper.exists('.non-editable'));
      });

      it('calls the contentUpdater function and exits edit mode when the buffer has changed', async function() {
        const contentUpdater = sinon.stub().resolves();

        const wrapper = shallowEditMode({
          originalContent: {id: 'id-0', body: 'original'},
          contentUpdater,
          render: () => <div className="non-editable" />,
        });

        wrapper.find('AtomTextEditor').prop('buffer').setText('different');
        await wrapper.find('.github-Review-updateCommentButton').prop('onClick')();
        assert.isTrue(contentUpdater.calledWith('id-0', 'different'));

        assert.isTrue(wrapper.exists('.non-editable'));
      });

      it('remains in editing mode and preserves the buffer text when unsuccessful', async function() {
        const contentUpdater = sinon.stub().rejects(new Error('oh no'));

        const wrapper = shallowEditMode({
          originalContent: {id: 'id-0', body: 'original'},
          contentUpdater,
          render: () => <div className="non-editable" />,
        });

        wrapper.find('AtomTextEditor').prop('buffer').setText('different');
        await wrapper.find('.github-Review-updateCommentButton').prop('onClick')();
        assert.isTrue(contentUpdater.calledWith('id-0', 'different'));

        assert.strictEqual(wrapper.find('AtomTextEditor').prop('buffer').getText(), 'different');
      });
    });

    describe('when the cancel button is clicked', function() {
      it('reverts to non-editing mode when the text is unchanged', async function() {
        const confirm = sinon.stub().returns(0);

        const wrapper = shallowEditMode({
          originalContent: {id: 'id-0', body: 'original'},
          confirm,
          render: () => <div className="original" />,
        });

        await wrapper.find('.github-Review-editableCancelButton').prop('onClick')();
        assert.isFalse(confirm.called);
        assert.isTrue(wrapper.exists('.original'));
      });

      describe('when the text has changed', function() {
        it('reverts to non-editing mode when the user confirms', async function() {
          const confirm = sinon.stub().returns(0);
          const contentUpdater = sinon.stub().resolves();

          const wrapper = shallowEditMode({
            originalContent: {id: 'id-0', body: 'original'},
            confirm,
            contentUpdater,
            render: () => <div className="original" />,
          });

          wrapper.find('AtomTextEditor').prop('buffer').setText('new text');
          await wrapper.find('.github-Review-editableCancelButton').prop('onClick')();
          assert.isTrue(confirm.called);
          assert.isFalse(contentUpdater.called);
          assert.isFalse(wrapper.exists('.github-Review-editable'));
          assert.isTrue(wrapper.exists('.original'));
        });

        it('remains in editing mode when the user cancels', async function() {
          const confirm = sinon.stub().returns(1);

          const wrapper = shallowEditMode({
            originalContent: {id: 'id-0', body: 'original'},
            confirm,
            render: () => <div className="original" />,
          });

          wrapper.find('AtomTextEditor').prop('buffer').setText('new text');
          await wrapper.find('.github-Review-editableCancelButton').prop('onClick')();
          assert.isTrue(confirm.called);
          assert.isTrue(wrapper.exists('.github-Review-editable'));
          assert.isFalse(wrapper.exists('.original'));
        });
      });
    });
  });
});
