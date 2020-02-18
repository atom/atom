import React from 'react';
import ReactDom from 'react-dom';
import {QueryRenderer, graphql} from 'react-relay';

import UserMentionTooltipContainer from '../containers/user-mention-tooltip-container';

export default class UserMentionTooltipItem {
  constructor(username, relayEnvironment) {
    this.username = username.substr(1);
    this.relayEnvironment = relayEnvironment;
  }

  getElement() {
    return this.element;
  }

  get element() {
    if (!this._element) {
      this._element = document.createElement('div');
      const rootContainer = (
        <QueryRenderer
          environment={this.relayEnvironment}
          query={graphql`
            query userMentionTooltipItemQuery($username: String!) {
              repositoryOwner(login: $username) {
                ...userMentionTooltipContainer_repositoryOwner
              }
            }
          `}
          variables={{
            username: this.username,
          }}
          render={({error, props, retry}) => {
            if (error) {
              return <div>Could not load information</div>;
            } else if (props) {
              return <UserMentionTooltipContainer {...props} />;
            } else {
              return (
                <div className="github-Loader">
                  <span className="github-Spinner" />
                </div>
              );
            }
          }}
        />
      );
      this._component = ReactDom.render(rootContainer, this._element);
    }

    return this._element;
  }

  destroy() {
    if (this._element) {
      ReactDom.unmountComponentAtNode(this._element);
      delete this._element;
    }
  }
}
