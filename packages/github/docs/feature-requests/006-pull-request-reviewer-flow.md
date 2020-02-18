**_Part 1 - Required information_**

# Pull Request Review -- Reviewer Flow

## :memo: Summary

Provide code review to an existing pull request within Atom.

*Note*: This RFC is an iteration of the [original RFC for Pull Request Review](./003-pull-request-review.md).

## :checkered_flag: Motivation

We already have an innovative review-comments-in-dock (RCID) workflow built out for the receiving end of pull request reviews. In order to complete the full code review experience within Atom, we should also build out a workflow for users to author pull request reviews.

## 🤯 Workflow Explanation

This is a high level overview of what the workflow of a PR Review author should look like. More on the functionality and behaviour of each component in the next section.

#### 1. Start a review

There are three ways to start a review:
1. Click "Start a review" button on the header of review dock, or footer of PR detail item, or on the empty state of review dock
2. [Respond to an existing review thread by clicking "Start a review"](#responding-to-a-comment-thread)
3. [Click on a "add comment" icon on the gutter](#add-comment-gutter-icon)

#### 2. Continue a review

Once a pending review has been started, user can add more comments to it by:
1. [Responding to an existing review thread](#responding-to-a-comment-thread)
2. [Clicking "add comment" icon on the gutter](#add-comment-gutter-icon)

#### 3. Submit a review
The only way to submit a review within Atom is by using the ["Submit review" button in the Pending Review tab](#summary-section). After publishing the review, the Pending Review tab will be destroyed. User will be led back to the All Reviews tab, which will immediately reflect the just published review.

## 🤯 Components Explanation


### "All Reviews" tab
This tab shows all review summaries and review comments, including the ones that are part of a _pending review_ that has not been submitted yet.

#### Header tabs
| header with no pending review | header with pending review |
|---|---|
|<img width="380" alt="new header" src="https://user-images.githubusercontent.com/6842965/57045364-57989b00-6c3b-11e9-8e95-309a17441d98.png">|<img width="380" alt="new header" src="https://user-images.githubusercontent.com/6842965/57045356-54051400-6c3b-11e9-8918-1ba043163c4d.png">|

- When there is no pending review, button reads "Start a new review", clicking on which will take you to the Pending Review tab in its empty state.
- When there is already a pending review, the button is replaced by a regular tab that reads "Pending Review (2)". The number is a counter of comments currently in the pending review. When adding more pending comments _within the All Reviews tab_ (more on that flow below), there should be some emphasis on the counter changing -- akin to the button on dotcom.

#### Responding to a comment thread
![responding to a comment thread](https://user-images.githubusercontent.com/6842965/56689748-cdd05700-66a9-11e9-90e8-266c69cbc589.png)

User can respond to a comment thread by adding a single line comment (current implementation) or starting a new review. The two buttons should only show up when the comment textbox is in focus, or is _not_ empty.

When there is already an existing pending review, there should only be **one** `btn-primary` button that reads "Comment".

#### Pending comments

![pending comment](https://user-images.githubusercontent.com/6842965/56692893-2ce59a00-66b1-11e9-81cc-bc7956bc8bec.png)

Pending comments within the All Reviews tab are styled differently from the already published comments. Pending comments contain a badge, and when clicked, will take user to the Pending Review tab.


### "Pending Review" tab
This tab shows *a subset* of all reviews -- only the summary and comments of a pending review. Since a user is only allowed to have one pending review at a time, there should also only be maximum one Pending Review tab.

#### Header (or the alternate footer)
The header looks very similar to the one of All Reviews tab, with the exception that the primary button now reads "See all reviews", and will send users back to the All Reviews tab.


#### Summary section

![pending review summary](https://user-images.githubusercontent.com/6842965/56699584-23196200-66c4-11e9-94a4-193c9d662bb3.png)

The summary section of the Pending Review tab is sticky (although still collapsible), so it stays within view regardless of how long the list of comments below it is. The icon on the left indicates the type of review, which can be selected in the dropdown underneath the text box. The button to submit review will be disabled a review type has not been chosen from the dropdown menu.


#### Comments section

![pending review comments](https://user-images.githubusercontent.com/6842965/56699828-31b44900-66c5-11e9-948c-a5c03215e5d8.png)

The comments section of the Pending Review tab looks very similar to that of the All Reviews tab, except that the progress bar is replaced by a small comment counter on top of the whole section.

**Empty State** of this section should contain a graphical tutorial of how to add a comment via gutter icon, along with a way to quickly navigate to the files changed tab so users can start adding comments right away.


### New Comment
![new comment](https://user-images.githubusercontent.com/6842965/56695406-fdd22700-66b6-11e9-9e7e-fe85e2507a66.png)

A new comment block can appear in either All Reviews tab or Pending Review tab, depending on the scenarios covered in [the section below](#add-comment-gutter-icon). When in focus, a new comment block always has a glowing border to emphasize itself. If there is already a pending review, there should only be one `btn-primary` button that reads "Comment".


### "Add comment" gutter icon

A user can start a review or add a comment to an existing pending review by clicking on the "add comment" icon which shows up on hover over the gutter of `MultiFilePatch` view within Files tab in `PullRequestDetailView`.

The flow of starting a review or adding a comment from the gutter varies a bit depending on the state of reviews:

* If there are no reviews at all
  1. User clicks on "add comment" icon in gutter
  2. *Pending Review* tab opens in empty state
  3. New comment block is added to the Pending Review tab


* If there are existing reviews and no pending review
  1. User clicks on "add comment" icon in gutter
  2. *All Reviews* tab open
  3. New comment block is added to the All Reviews tab
  4. User can choose between "Add a single comment" or "start a review"
  5. (a) "add single comment": comment is added to the All Reviews tab; (b) "start a review": user is redirected to the pending tab with the newly added pending comment there


* If there is a pending review
  1. User clicks on "add comment" icon in gutter
  2. *Pending reviews* tab open
  3. New comment block is added to the Pending Review tab


## :anchor: Drawbacks

None considered, since this is a crucial part of a holistic pull request review experience.

## :thinking: Rationale and alternatives

Since we have already decided and implemented review tab to _view_ PR review, it makes sense to extend the tab's functionality to include the capability of authoring a review.

## :warning: Out of Scope

- Allowing review comments to be left in regions _outside of_ the modified region of a PR
- Adding comments from editor instead of just from files changed tab in `PRDetailView`

## :construction: Implementation phases

An "edit comment" functionality will be needed for this feature. It can be a standalone piece that gets tackled separately, before starting the PR review authoring experience.

## :white_check_mark: Feature description for Atom release blog post

TBD
