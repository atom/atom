import React from 'react';
import {Range} from 'atom';
import PropTypes from 'prop-types';
import {EndpointPropType} from '../prop-types';
import Decoration from '../atom/decoration';
import Marker from '../atom/marker';
import ReviewsItem from '../items/reviews-item';
import {addEvent} from '../reporter-proxy';

export default class CommentGutterDecorationController extends React.Component {
  static propTypes = {
    commentRow: PropTypes.number.isRequired,
    threadId: PropTypes.string.isRequired,
    extraClasses: PropTypes.array,

    workspace: PropTypes.object.isRequired,
    endpoint: EndpointPropType.isRequired,
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    number: PropTypes.number.isRequired,
    workdir: PropTypes.string.isRequired,
    editor: PropTypes.object,

    // For metric reporting
    parent: PropTypes.string.isRequired,
  };

  static defaultProps = {
    extraClasses: [],
  }

  render() {
    const range = Range.fromObject([[this.props.commentRow, 0], [this.props.commentRow, Infinity]]);
    return (
      <Marker
        key={`github-comment-gutter-decoration-${this.props.threadId}`}
        editor={this.props.editor}
        exclusive={true}
        invalidate="surround"
        bufferRange={range}>
        <Decoration
          editor={this.props.editor}
          type="gutter"
          gutterName="github-comment-icon"
          className={`github-editorCommentGutterIcon ${this.props.extraClasses.join(' ')}`}
          omitEmptyLastRow={false}>
          <button className="icon icon-comment" onClick={() => this.openReviewThread(this.props.threadId)} />
        </Decoration>
      </Marker>
    );
  }

  async openReviewThread(threadId) {
    const uri = ReviewsItem.buildURI({
      host: this.props.endpoint.getHost(),
      owner: this.props.owner,
      repo: this.props.repo,
      number: this.props.number,
      workdir: this.props.workdir,
    });
    const reviewsItem = await this.props.workspace.open(uri, {searchAllPanes: true});
    reviewsItem.jumpToThread(threadId);
    addEvent('open-review-thread', {package: 'github', from: this.props.parent});
  }

}
