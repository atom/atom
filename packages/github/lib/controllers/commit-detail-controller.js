import React from 'react';
import PropTypes from 'prop-types';

import CommitDetailView from '../views/commit-detail-view';

export default class CommitDetailController extends React.Component {
  static propTypes = {
    ...CommitDetailView.drilledPropTypes,

    commit: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    this.state = {
      messageCollapsible: this.props.commit.isBodyLong(),
      messageOpen: !this.props.commit.isBodyLong(),
    };
  }

  render() {
    return (
      <CommitDetailView
        messageCollapsible={this.state.messageCollapsible}
        messageOpen={this.state.messageOpen}
        toggleMessage={this.toggleMessage}
        {...this.props}
      />
    );
  }

  toggleMessage = () => {
    return new Promise(resolve => {
      this.setState(prevState => ({messageOpen: !prevState.messageOpen}), resolve);
    });
  }
}
