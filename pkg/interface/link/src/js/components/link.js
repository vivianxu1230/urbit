import React, { Component } from 'react'
import { LinksTabBar } from './lib/links-tabbar';
import { SidebarSwitcher } from '/components/lib/icons/icon-sidebar-switch.js';
import { api } from '../api';
import { Route, Link } from 'react-router-dom';
import { Comments } from './lib/comments';
import { base64urlEncode } from '../lib/util';

export class LinkDetail extends Component {
  constructor(props) {
    super(props);
    this.state = {
      comment: "",
      data: props.data
    };

    this.setComment = this.setComment.bind(this);
  }

  updateData(submission) {
    this.setState({
      data: submission
    });
  }

  componentDidMount() {
    // if we have no preloaded data, and we aren't expecting it, get it
    if (!this.state.data.title) {
      api.getSubmission(
        this.props.groupPath, this.props.url, this.updateData.bind(this)
      );
    }
  }

  componentDidUpdate(prevProps) {
    if (this.props.url !== prevProps.url) {
      this.updateData(this.props.data);
    }
  }

  onClickPost() {
    let url = this.props.url || "";

    let request = api.postComment(
      this.props.groupPath,
      url,
      this.state.comment
    );

    if (request) {
      this.setState({ comment: "" });
    }
  }

  setComment(event) {
    this.setState({ comment: event.target.value });
  }

  render() {
    let props = this.props;
    let popout = (props.popout) ? "/popout" : "";

    const data = this.state.data || props.data;
    let ship = data.ship || "zod";
    let title = data.title || "";
    let url = data.url || "";

    const commentCount = props.comments
      ? props.comments.totalItems
      : data.commentCount || 0;

    let comments = commentCount + " comment" + (commentCount === 1 ? "" : "s");

    let nickname = !!props.members[ship] ? props.members[ship].nickname : "";

    let activeClasses = this.state.comment
      ? "black b--black pointer"
      : "gray2 b--gray2";

    return (
      <div className="h-100 w-100 overflow-hidden flex flex-column">
        <div
          className={`pl3 pt2 flex relative overflow-x-scroll
      overflow-x-auto-l overflow-x-auto-xl flex-shrink-0
      bb bn-m bn-l bn-xl b--gray4`}
          style={{ height: 48 }}>
          <SidebarSwitcher
            sidebarShown={props.sidebarShown}
            popout={props.popout}
          />
          <Link
            className="dib f8 fw4 v-top pt2 gray2"
            to={"/~link" + popout + props.groupPath + "/" + props.page}>
            {"<- Collection index"}
          </Link>
          <LinksTabBar {...props} popout={popout} groupPath={props.groupPath} />
        </div>
        <div className="w-100 mt2 flex justify-center overflow-y-scroll ph4 pb4">
          <div className="w-100 mw7">
            <LinkPreview
              title={title}
              url={url}
              comments={comments}
              nickname={nickname}
              ship={ship}
              path={props.groupPath}
              page={props.page}
              linkIndex={props.linkIndex}
              data={props.data}
            />
            <div className="relative ba br1 b--gray4 b--gray2-d mt6 mb6">
              <textarea
                className="w-100 bg-gray0-d white-d f8 pa2 pr8"
                style={{
                  resize: "none",
                  height: 75
                }}
                placeholder="Leave a comment on this link"
                onChange={this.setComment}
                value={this.state.comment}
              />
              <button
                className={
                  "f8 bg-gray0-d white-d ml2 absolute " + activeClasses
                }
                disabled={!this.state.comment}
                onClick={this.onClickPost.bind(this)}
                style={{
                  bottom: 12,
                  right: 8
                }}>
                Post
              </button>
            </div>
            <Comments
              groupPath={props.groupPath}
              key={props.groupPath + props.commentPage}
              comments={props.comments}
              commentPage={props.commentPage}
              members={props.members}
              popout={props.popout}
              url={props.url}
              linkPage={props.page}
              linkIndex={props.linkIndex}
            />
          </div>
        </div>
      </div>
    );
  }
}

export default LinkDetail;
