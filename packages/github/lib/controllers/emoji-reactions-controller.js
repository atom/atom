import PropTypes from 'prop-types';
import React from 'react';
import {createFragmentContainer, graphql} from 'react-relay';

import EmojiReactionsView from '../views/emoji-reactions-view';
import addReactionMutation from '../mutations/add-reaction';
import removeReactionMutation from '../mutations/remove-reaction';

export class BareEmojiReactionsController extends React.Component {
  static propTypes = {
    relay: PropTypes.shape({
      environment: PropTypes.object.isRequired,
    }).isRequired,
    reactable: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }).isRequired,

    // Atom environment
    tooltips: PropTypes.object.isRequired,

    // Action methods
    reportRelayError: PropTypes.func.isRequired,
  }

  render() {
    return (
      <EmojiReactionsView
        addReaction={this.addReaction}
        removeReaction={this.removeReaction}
        {...this.props}
      />
    );
  }

  addReaction = async content => {
    try {
      await addReactionMutation(this.props.relay.environment, this.props.reactable.id, content);
    } catch (err) {
      this.props.reportRelayError('Unable to add reaction emoji', err);
    }
  };

  removeReaction = async content => {
    try {
      await removeReactionMutation(this.props.relay.environment, this.props.reactable.id, content);
    } catch (err) {
      this.props.reportRelayError('Unable to remove reaction emoji', err);
    }
  };
}

export default createFragmentContainer(BareEmojiReactionsController, {
  reactable: graphql`
    fragment emojiReactionsController_reactable on Reactable {
      id
      ...emojiReactionsView_reactable
    }
  `,
});
