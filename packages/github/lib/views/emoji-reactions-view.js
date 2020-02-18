import PropTypes from 'prop-types';
import React from 'react';
import {createFragmentContainer, graphql} from 'react-relay';
import cx from 'classnames';

import ReactionPickerController from '../controllers/reaction-picker-controller';
import Tooltip from '../atom/tooltip';
import RefHolder from '../models/ref-holder';
import {reactionTypeToEmoji} from '../helpers';

export class BareEmojiReactionsView extends React.Component {
  static propTypes = {
    // Relay response
    reactable: PropTypes.shape({
      id: PropTypes.string.isRequired,
      reactionGroups: PropTypes.arrayOf(
        PropTypes.shape({
          content: PropTypes.string.isRequired,
          viewerHasReacted: PropTypes.bool.isRequired,
          users: PropTypes.shape({
            totalCount: PropTypes.number.isRequired,
          }).isRequired,
        }),
      ).isRequired,
      viewerCanReact: PropTypes.bool.isRequired,
    }).isRequired,

    // Atom environment
    tooltips: PropTypes.object.isRequired,

    // Action methods
    addReaction: PropTypes.func.isRequired,
    removeReaction: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.refAddButton = new RefHolder();
    this.refTooltip = new RefHolder();
  }

  render() {
    const viewerReacted = this.props.reactable.reactionGroups
      .filter(group => group.viewerHasReacted)
      .map(group => group.content);
    const {reactionGroups} = this.props.reactable;
    const showAddButton = reactionGroups.length === 0 || reactionGroups.some(g => g.users.totalCount === 0);

    return (
      <div className="github-EmojiReactions btn-toolbar">
        {showAddButton && (
          <div className="btn-group">
            <button
              className="github-EmojiReactions-add btn icon icon-smiley"
              ref={this.refAddButton.setter}
              disabled={!this.props.reactable.viewerCanReact}
            />
            <Tooltip
              manager={this.props.tooltips}
              target={this.refAddButton}
              trigger="click"
              className="github-Popover"
              refTooltip={this.refTooltip}>
              <ReactionPickerController
                viewerReacted={viewerReacted}
                addReaction={this.props.addReaction}
                removeReaction={this.props.removeReaction}
                tooltipHolder={this.refTooltip}
              />
            </Tooltip>
          </div>
        )}
        <div className="btn-group">
          {this.props.reactable.reactionGroups.map(group => {
            const emoji = reactionTypeToEmoji[group.content];
            if (!emoji) {
              return null;
            }
            if (group.users.totalCount === 0) {
              return null;
            }

            const className = cx(
              'github-EmojiReactions-group',
              'btn',
              group.content.toLowerCase(),
              {selected: group.viewerHasReacted},
            );

            const toggle = !group.viewerHasReacted
              ? () => this.props.addReaction(group.content)
              : () => this.props.removeReaction(group.content);

            const disabled = !this.props.reactable.viewerCanReact;

            return (
              <button key={group.content} className={className} onClick={toggle} disabled={disabled}>
                {reactionTypeToEmoji[group.content]} &nbsp; {group.users.totalCount}
              </button>
            );
          })}
        </div>
      </div>
    );
  }
}

export default createFragmentContainer(BareEmojiReactionsView, {
  reactable: graphql`
    fragment emojiReactionsView_reactable on Reactable {
      id
      reactionGroups {
        content
        viewerHasReacted
        users {
          totalCount
        }
      }
      viewerCanReact
    }
  `,
});
