import React from 'react';
import PropTypes from 'prop-types';

import ReactionPickerView from '../views/reaction-picker-view';
import {RefHolderPropType} from '../prop-types';
import {addEvent} from '../reporter-proxy';

export default class ReactionPickerController extends React.Component {
  static propTypes = {
    addReaction: PropTypes.func.isRequired,
    removeReaction: PropTypes.func.isRequired,

    tooltipHolder: RefHolderPropType.isRequired,
  }

  render() {
    return (
      <ReactionPickerView
        addReactionAndClose={this.addReactionAndClose}
        removeReactionAndClose={this.removeReactionAndClose}
        {...this.props}
      />
    );
  }

  addReactionAndClose = async content => {
    await this.props.addReaction(content);
    addEvent('add-emoji-reaction', {package: 'github'});
    this.props.tooltipHolder.map(tooltip => tooltip.dispose());
  }

  removeReactionAndClose = async content => {
    await this.props.removeReaction(content);
    addEvent('remove-emoji-reaction', {package: 'github'});
    this.props.tooltipHolder.map(tooltip => tooltip.dispose());
  }
}
