# Pull Request Review

## Status

Accepted

## Summary

Give and receive code reviews on pull requests within Atom.

## Motivation

Workflows around pull request reviews involve many trips between your editor and your browser. If you check out a pull request locally to test it and want to leave comments, you need to map the issues that you've found in your working copy back to lines on the diff to comment appropriately. Similarly, when you're given a review, you have to mentally correlate review comments on the diff on GitHub with the corresponding lines in your local working copy, then map _back_ to diff lines to respond once you've established context. By revealing review comments as decorations directly within the editor, we can eliminate all of these round-trips and streamline the review process for all involved.

Peer review is also a critical part of the path to acceptance for pull requests in many common workflows. By surfacing progress through code review, we provide context on the progress of each unit of work alongside existing indicators like commit status.

## Explanation

### Pull Request list

![image](https://user-images.githubusercontent.com/378023/51304737-4658c380-1a7c-11e9-8edb-7ceafeedabe5.png)

* Review progress is indicated for open pull requests listed in the GitHub panel.
* The pull request corresponding to the checked out branch gets special treatment in its own section at the top of the list.

![center pane](https://user-images.githubusercontent.com/378023/51305096-45746180-1a7d-11e9-801b-37b3ab0c862a.png)

* Clicking a pull request in the list opens a `PullRequestDetailItem` in the workspace center.
* Clicking the progress bar opens a `PullRequestReviewsItem` in the left dock.

### PullRequestDetailItem

#### Header

![header](https://user-images.githubusercontent.com/378023/51305325-e400c280-1a7d-11e9-9b4e-b9cf2d326dd5.png)

At the top of each `PullRequestDetailItem` is a summary about the pull request, followed by the tabs to switch between different sub-views.

- Overview
- Files (**new**)
- Commits
- Build Status

Below the tabs is a "tools bar" with controls to toggle review comments or collapse files.

#### Footer

![reviews panel](https://user-images.githubusercontent.com/3781742/53611708-5805ae80-3b84-11e9-915d-fb29476e3001.png)

A panel at the bottom of the pane shows the progress for resolved review comments. It also has a "Review Changes" button to create a new review. This panel is persistent throughout all sub-views. It allows creating new reviews no matter where you are.

When the pull request is checked out, an "Open Reviews" button is shown in the review footer. Clicking "Open Reviews" opens a `PullRequestReviewsItem` for this pull request's review comments as an item in the right workspace dock.

### Files (tab)

Clicking on the "Files Changed" tab displays the full, multi-file diff associated with the pull request. This is akin to the "Files changed" tab on dotcom.

![files](https://user-images.githubusercontent.com/378023/51305826-43ab9d80-1a7f-11e9-8b41-42bc4812d214.png)


Diffs are editable, but _only_ if the pull request branch is checked out and the local branch history has not diverged incompatibly from the remote branch history.

For large diffs, the files can be collapsed to get a better overview.

Uncollapsed (default) | Collapsed
--- | ---
![files](https://user-images.githubusercontent.com/378023/46536560-d3bb4200-c8e9-11e8-9764-dca0b84245cf.png) | ![collapsed files](https://user-images.githubusercontent.com/378023/46931273-7069a680-d085-11e8-9ea7-c96a1772fe27.png)

#### Create a new review

##### `+` Button

Hovering along the gutter within a pull request diff region in a `TextEditor` or a `PullRequestDetailItem` reveals a `+` icon. Clicking the `+` icon reveals a new comment box, which may be used to submit a single comment or start a multi-comment review:

![new review](https://user-images.githubusercontent.com/378023/46926996-49ec4100-d06e-11e8-9fb7-86607861efdd.png)

* Clicking "Add single comment" submits a diff comment and does not create a draft review.
* Clicking "Start a review" creates a draft review and attaches the authored comment to it.

##### Pending comments

![pending review](https://user-images.githubusercontent.com/378023/46927357-e06d3200-d06f-11e8-9eae-b4c289fe16ae.png)

* If a draft review is already in progress, the "Start a review" button reads "Add review comment".
* An additional row is added with options to "Start a new conversation" or "Finish your review".

##### Submit a review

Clicking "Finish your review" from a comment or clicking "Review Changes" in the footer...

![reviews panel](https://user-images.githubusercontent.com/378023/46536010-17ad4780-c8e8-11e8-8338-338bb592efc5.png)

... expands the footer to:

![submit review](https://user-images.githubusercontent.com/378023/46927736-ef54e400-d071-11e8-99d9-0ea1001fc50d.png)

* The review summary is a TextEditor that may be used to compose a summary comment.
* Files with pending review comments are listed and make it possible to navigate between them.
* A review can be marked as "Comment", "Approve" or "Recommend changes" (.com's "Request changes").
* Choosing "Cancel" dismisses the review and any comments made. If there are local review comments that will be lost, a confirmation prompt is shown first.
* Choosing "Submit review" submits the drafted review to GitHub.

##### Resolve a comment

![resolve a review](https://user-images.githubusercontent.com/378023/46927875-c08b3d80-d072-11e8-978b-024111312d79.png)

* Review comments can be resolved by clicking on the "Mark as resolved" buttons.
* If the "reply..." editor has non-whitespace content, it is submitted as a final comment first.

### PullRequestReviewsItem

This item is opened in the workspace's right dock when the user:

* Clicks the review progress bar in the GitHub tab.
* Clicks the "open reviews" button on the review summary footer of a `PullRequestDetailItem`.
* Clicks the "<>" button on a review comment in the "Files Changed" tab of a `PullRequestDetailItem`.

It shows a scrollable view of all of the reviews and comments associated with a specific pull request,

![pull request reviews item](https://user-images.githubusercontent.com/3781742/53610984-c85f0080-3b81-11e9-9a82-9df43b6410f3.png)

Reviews are sorted by "urgency," showing reviews that still need to be addressed at the top. Within each group, sorting is done by "newest first".

1. "recommended" changes
2. "commented" changes
3. "no review" (when a reviewer only leaves review comments, but no summary)
4. "approved" changes
5. "previous" reviews (when a reviewer made an earlier review and it's now out-dated)

Clicking on a review summary comment expands or collapses the associated review comments.

<img width="429" alt="screen shot 2019-02-28 at 6 03 50 pm" src="https://user-images.githubusercontent.com/3781742/53611421-5a1b3d80-3b83-11e9-9e50-ac4c54a67c13.png">

In addition to the comment, users see an abbreviated version of the diff, with 4 context lines. 

Clicking on the "Jump To File" button opens a `TextEditor` on the corresponding position of the file under review. The clicked review comment is highlighted as the "current" one.

Clicking on the "View Changes" button opens the "Files" tab of the `PullRequestDetailsView`, so the user can see the full diff. 


#### Within an open TextEditor

If an open `TextEditor` corresponds to a file that has one or more review comments in an open `PullRequestReviewsItem`, gutter and line decorations are added to the lines that match those review comment positions. The "current" one is styled differently to stand out.

![inline diff](https://user-images.githubusercontent.com/378023/51360052-68e6ed00-1b0d-11e9-852e-a51cff4d479e.png)

Clicking on the gutter icon reveals the `PullRequestReviewsItem` and highlights that review comment as the "current" one, scrolling to it and expanding its review if necessary.

### Context and navigation

Review comments are shown in 3 different places. The comments themselves have the same functionality, but allow the comment to be seen in a different context, depending on different use cases. For example "reviewing a pull request", "addressing feedback", "editing the entire file".

Files | Reviews | Single file
--- | --- | ---
![files](https://user-images.githubusercontent.com/378023/46932382-6bf3bc80-d08a-11e8-83ce-af2ec99c3610.png) | ![reviews](https://user-images.githubusercontent.com/378023/46535563-c81a4c00-c8e6-11e8-9c0b-6ea575556101.png) | ![single file](https://user-images.githubusercontent.com/378023/46928308-e9accd80-d074-11e8-8de3-a16140e74907.png)

In order to navigate between comments or switch context, each comment has the following controls:

![image](https://user-images.githubusercontent.com/378023/46934191-c6444b80-d091-11e8-9405-b93bd2aecc90.png)

* Clicking on the `<>` button in a review comment shows the comment in the entire file. If possible, the scroll-position is retained. This allows to quickly get more context about the code.
  * If the current pull request is not checked out, the `<>` button is disabled, and a tooltip prompts the user to check out the pull request to edit the source.
* Clicking on the "sandwich" button shows the comment in the corresponding `PullRequestReviewsItem`.
* Clicking on the "file-+" button (not shown in above screenshot) shows the comment under the "Files Changed" tab.
* The up and down arrow buttons navigate to the next and previous unresolved review comments.
* Reaction emoji may be added to each comment with the "emoji" button. Existing emoji reaction tallies are included beneath each comment.

Another way to navigate between unresolved comments is to collapse all files first. Files that contain unresolved comments have a "[n] unresolved" button on the right, making it easy to find them.

![files with unresolved comments](https://user-images.githubusercontent.com/378023/46986769-022bef00-d12c-11e8-8839-279fb0d03fb1.png)

* Clicking that button uncollapses the file (if needed) and scrolls to the position of the comment.


## Drawbacks

This adds a substantial amount of complexity to the UI, which is only justified for users that use GitHub pull request reviews.


## Rationale and alternatives

#### First iteration

Our original design looked and felt very dotcom-esque:

![changes-tab](https://user-images.githubusercontent.com/378023/46287431-6e9bdf80-c5bd-11e8-99eb-f3f81ba64e81.png)

We decided to switch to an editor-first approach and build the code review experience around an actual TextEditor item with a custom diff view. We are breaking free of the dotcom paradigm and leveraging the fact that we are in the context of the user's working directory, where we can easily update code.

We discussed displaying review summary information in the GitHub panel in a ["Current pull request tile"](https://github.com/atom/github/blob/2ab74b59873c3b5bccac7ef679795eb483b335cf/docs/rfcs/XXX-pull-request-review.md#current-pull-request-tile). The current design encapsulates all of the PR information and functionality within a `PullRequestDetailItem`. Keeping the GitHub panel free of PR details for a specific PR rids us of the problem of having to keep it updated when the user switches active repos (which can feel jarring). This also avoids confusing the user by showing PR details for different PRs (imagine the checked out PR info in the panel and a pane item with PR info for a separate repo). We also free up space in the GitHub panel, making it less busy/overwhelming and leaving room for other information we might want to provide there in the future (like associated issues, say).

#### Second iteration

Our 2nd iteration made the changes of a PR be the main focus when opening a `PullRequestDetailItem`.

![filter](https://user-images.githubusercontent.com/7910250/46391711-1df6b600-c693-11e8-87f3-ad4cdbe8ebd8.png)

It was a great improvement, but filtering the diff with radio buttons and checkboxes felt confusing and overwhelming. Our next iteration then had the following goals:

- Bring back the sub-navigation, but make it look less .com-y.
- Keep using an editable editor for the diffs, but add some padding.
- Introduce a "Reviews" footer to all sub-views to allow creating/submit a review, no matter where you are.

#### Third iteration

Long comments can disrupt the code editing experience.  Our third iteration keeps the review comments in a dock, a la Google Docs.  This helps code authors more easily address comments, because they can see the comments and also get them out of the way.

Since this approach different from previous approaches, we performed a series of [usability studies](https://github.com/github/pe-editor-tools/blob/master/community/usability-testing/atom_rcid_research_summary.md) to validate that users would find this approach useful.

We may at some point want to migrate the entire PullRequestDetailView from the pane item to the dock, so as not to duplicate information.  However, in the interest of getting code review in the editor shipped, we'll keep the pane item around in the short term.


## Unresolved questions

### Questions I expect to address before this is merged

* Can we access "draft" reviews from the GitHub API, to unify them between Atom and GitHub?
  * _Yes, the `reviews` object includes it in a `PENDING` state._
* How do we represent the resolution of a comment thread? Where can we reveal this progress through each review, and of all required reviews?
  * _We'll show a progress bar in the footer of the `PullRequestDetailItem`._
* Are there any design choices we can make to lessen the emotional weight of a "requests changes" review? Peer review has the most value when it discovers issues for the pull request author to address, but accepting criticism is a vulnerable moment.
  * _Choosing phrasing and iconography carefully for "recommend changes"._
* Similarly, are there any ways we can encourage empathy within the review authoring process? Can we encourage reviewers to make positive comments or demonstrate humility and open-mindedness?
  * _Emoji reactions on comments :cake: :tada:_
  * _Enable integration with Teletype for smoother jumping to a synchronous review_

### Questions I expect to resolve throughout the implementation process

* When there are working directory changes or local commits on the PR branch, how do we clearly indicate them within the diff view? Do we need to make them visually distinct from the PR changes? Things might get confusing for the user when the diff in the editor gets out of sync with the diff on dotcom. For example: a pull request author reads a comment pointing out a typo in an added line. The author edits text within the multi-file diff which modifies the working directory. Should this line now be styled differently to indicate that it has deviated from the original diff?
* Review comment positioning within live TextEditors will be a tricky problem to address satisfactorily. What are the edge cases we need to handle there?
  * _Review comments on deleted lines._
  * _Review comments on deleted files._
* The GraphQL API paths we need to interact with all involve multiple levels of pagination: pull requests, pull request reviews, review comments. How do we handle these within Relay? Or do we interact directly with GraphQL requests?
* How do we handle comment threads?
* When editing diffs:
  * Do we edit the underlying buffer or file directly, or do we mark the `PullRequestDetailItem` as "modified" and require a "save" action to persist changes?
  * Do we disallow edits of removed lines, or do we re-introduce the removed line as an addition on modification?
* When clicking on the `<>` button, should there be a way to turn of the diff? Or when opening the same file from the tree-view, should we show review comments? Or only an icon in the gutter?

### Questions I consider out of scope of this Feature Request

* What other pull request information can we add to the GitHub pane item?
* How can we notify users when new information, including reviews, is available, preferably without being intrusive or disruptive?

## Implementation phases

![dependency-graph](https://user-images.githubusercontent.com/17565/46475622-019e6a80-c7b4-11e8-9bf5-8223d5c6631f.png)

## Related features out of scope of this Feature Request

* "Find" input field for filtering based on search term (which could be a file name, an author, a variable name, etc)
