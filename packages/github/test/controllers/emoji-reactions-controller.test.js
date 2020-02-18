import React from 'react';
import {shallow} from 'enzyme';
import {create as createRecord} from 'relay-runtime/lib/RelayModernRecord';

import {BareEmojiReactionsController} from '../../lib/controllers/emoji-reactions-controller';
import EmojiReactionsView from '../../lib/views/emoji-reactions-view';
import {issueBuilder} from '../builder/graphql/issue';
import {relayResponseBuilder} from '../builder/graphql/query';
import RelayNetworkLayerManager, {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {getEndpoint} from '../../lib/models/endpoint';

import reactableQuery from '../../lib/controllers/__generated__/emojiReactionsController_reactable.graphql';
import addReactionQuery from '../../lib/mutations/__generated__/addReactionMutation.graphql';
import removeReactionQuery from '../../lib/mutations/__generated__/removeReactionMutation.graphql';

describe('EmojiReactionsController', function() {
  let atomEnv, relayEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    relayEnv = RelayNetworkLayerManager.getEnvironmentForHost(getEndpoint('github.com'), '1234');
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      relay: {
        environment: relayEnv,
      },
      reactable: issueBuilder(reactableQuery).build(),
      tooltips: atomEnv.tooltips,
      reportRelayError: () => {},
      ...override,
    };

    return <BareEmojiReactionsController {...props} />;
  }

  it('renders an EmojiReactionView and passes props', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    assert.strictEqual(wrapper.find(EmojiReactionsView).prop('extra'), extra);
  });

  describe('adding a reaction', function() {
    it('fires the add reaction mutation', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addReactionQuery.operation.name,
        variables: {input: {content: 'ROCKET', subjectId: 'issue0'}},
      }, op => {
        return relayResponseBuilder(op)
          .addReaction(m => {
            m.subject(r => r.beIssue());
          })
          .build();
      }).resolve();

      const reactable = issueBuilder(reactableQuery).id('issue0').build();
      relayEnv.getStore().getSource().set('issue0', {...createRecord('issue0', 'Issue'), ...reactable});

      const wrapper = shallow(buildApp({reactable, reportRelayError}));

      await wrapper.find(EmojiReactionsView).prop('addReaction')('ROCKET');

      assert.isFalse(reportRelayError.called);
    });

    it('reports errors encountered', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addReactionQuery.operation.name,
        variables: {input: {content: 'EYES', subjectId: 'issue1'}},
      }, op => {
        return relayResponseBuilder(op)
          .addError('oh no')
          .build();
      }).resolve();

      const reactable = issueBuilder(reactableQuery).id('issue1').build();
      relayEnv.getStore().getSource().set('issue1', {...createRecord('issue1', 'Issue'), ...reactable});

      const wrapper = shallow(buildApp({reactable, reportRelayError}));

      await wrapper.find(EmojiReactionsView).prop('addReaction')('EYES');

      assert.isTrue(reportRelayError.calledWith(
        'Unable to add reaction emoji',
        sinon.match({errors: [{message: 'oh no'}]})),
      );
    });
  });

  describe('removing a reaction', function() {
    it('fires the remove reaction mutation', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: removeReactionQuery.operation.name,
        variables: {input: {content: 'THUMBS_DOWN', subjectId: 'issue0'}},
      }, op => {
        return relayResponseBuilder(op)
          .removeReaction(m => {
            m.subject(r => r.beIssue());
          })
          .build();
      }).resolve();

      const reactable = issueBuilder(reactableQuery).id('issue0').build();
      relayEnv.getStore().getSource().set('issue0', {...createRecord('issue0', 'Issue'), ...reactable});

      const wrapper = shallow(buildApp({reactable, reportRelayError}));

      await wrapper.find(EmojiReactionsView).prop('removeReaction')('THUMBS_DOWN');

      assert.isFalse(reportRelayError.called);
    });

    it('reports errors encountered', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: removeReactionQuery.operation.name,
        variables: {input: {content: 'CONFUSED', subjectId: 'issue1'}},
      }, op => {
        return relayResponseBuilder(op)
          .addError('wtf')
          .build();
      }).resolve();

      const reactable = issueBuilder(reactableQuery).id('issue1').build();
      relayEnv.getStore().getSource().set('issue1', {...createRecord('issue1', 'Issue'), ...reactable});

      const wrapper = shallow(buildApp({reactable, reportRelayError}));

      await wrapper.find(EmojiReactionsView).prop('removeReaction')('CONFUSED');

      assert.isTrue(reportRelayError.calledWith(
        'Unable to remove reaction emoji',
        sinon.match({errors: [{message: 'wtf'}]})),
      );
    });
  });
});
