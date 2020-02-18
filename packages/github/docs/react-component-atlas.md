# React Component Atlas

This is a high-level overview of the structure of the React component tree that this package creates. It's intended _not_ to be comprehensive, but to give you an idea of where to find specific bits of functionality.

> [`<RootController>`](/lib/controllers/root-controller.js)
>
> Root of the entire, unified React component tree. Mostly responsible for registering pane items, status bar tiles, workspace commands, and managing dialog box state. Action methods that are shared across broad swaths of the component tree.
>
> > [`<GitTabItem>`](/lib/items/git-tab-item.js)
> > [`<GitTabContainer>`](/lib/containers/git-tab-container.js)
> > [`<GitTabController>`](/lib/controllers/git-tab-controller.js)
> > [`<GitTabView>`](/lib/views/git-tab-view.js)
> >
> > The "Git" tab that appears in the right dock (by default).
> >
> > > [`<StagingView>`](/lib/views/staging-view.js)
> > >
> > > The lists of unstaged changes, staged changes, and merge conflicts.
> >
> > > [`<CommitController>`](/lib/controllers/commit-controller.js)
> > > [`<CommitView>`](/lib/views/commit-view.js)
> > >
> > > The commit message editor, submit button, and co-author selection controls.
> >
> > > [`<RecentCommitsController>`](/lib/controllers/recent-commits-controller.js)
> > > [`<RecentCommitsView>` `<RecentCommitView>`](/lib/views/recent-commits-view.js)
> > >
> > > List of most recent commits on the current branch.
>
> > [`<GitHubTabItem>`](/lib/items/github-tab-item.js)
> > [`<GitHubTabContainer>`](/lib/containers/github-tab-container.js)
> > [`<GitHubTabController>`](/lib/controllers/github-tab-controller.js)
> > [`<GitHubTabView>`](/lib/views/github-tab-view.js)
> >
> > The "GitHub" tab that appears in the right dock (by default).
> >
> > > [`<RemoteSelectorView>`](/lib/views/remote-selector-view.js)
> > >
> > > Shown if the current repository has more than one remote that's identified as a github.com remote.
> >
> > > [`<RemoteContainer>`](/lib/containers/remote-container.js)
> > > [`<RemoteController>`](/lib/controllers/remote-controller.js)
> > >
> > > GraphQL query and actions that only require the context of a unique repository name to work.
> > >
> > > > [`<IssueishSearchesController>`](/lib/controllers/issueish-searches-controller.js)
> > > >
> > > > Manages the set of GitHub API issueish searches that we wish to perform, including the special "checked-out pull request" search.
> > > >
> > > > > [`<CurrentPullRequestContainer>`](/lib/containers/current-pull-request-container.js)
> > > > > [`<CreatePullRequestTile>`](/lib/views/create-pull-request-tile.js)
> > > > >
> > > > > GraphQL query and result rendering for the special "checked-out pull request" search.
> > > >
> > > > > [`<IssueishListController>`](/lib/controllers/issueish-list-controller.js)
> > > > > [`<IssueishListView>`](/lib/views/issueish-list-view.js)
> > > > >
> > > > > Render an issueish result as a row within the result list of the current pull request tile.
> > > >
> > > > > [`<IssueishSearchContainer>`](/lib/containers/issueish-search-container.js)
> > > > >
> > > > > GraphQL query and result rendering for an issueish search based on the [`search()`](https://developer.github.com/v4/query/#search) GraphQL connection.
> > > > >
> > > > > > [`<IssueishListController>`](/lib/controllers/issueish-list-controller.js)
> > > > > > [`<IssueishListView>`](/lib/views/issueish-list-view.js)
> > > > > >
> > > > > > Render a list of issueish results as rows within the result list of a specific search.
>
> > [`<ChangedFileItem>`](/lib/items/changed-file-item.js)
> > [`<ChangedFileContainer>`](/lib/containers/changed-file-container.js)
> >
> > The workspace-center pane that appears when looking at the staged or unstaged changes associated with a file.
> >
> > > [`<MultiFilePatchController>`](/lib/controllers/multi-file-patch-controller.js)
> > > [`<MultiFilePatchView>`](/lib/views/multi-file-patch-view.js)
> > >
> > > Render a sequence of git-generated file patches within a TextEditor, using decorations to include contextually relevant controls.
> > > See [`MultiFilePatchView` atlas](#multifilepatchview-atlas) below for a more detailed breakdown.
>
> > [`<CommitPreviewItem>`](/lig/items/commit-preview-item.js)
> > [`<CommitPreviewContainer>`](/lib/containers/commit-preview-container.js)
> >
> > The workspace-center pane item that appears when looking at _all_ the staged changes that will be going into the next commit.
> >
> > > [`<MultiFilePatchController>`](/lib/controllers/multi-file-patch-controller.js)
> > > [`<MultiFilePatchView>`](/lib/views/multi-file-patch-view.js)
>
> > [`<CommitDetailItem>`](/lib/items/issueish-detail-item.js)
> > [`<CommitDetailContainer>`](/lib/containers/commit-detail-container.js)
> > [`<CommitDetailController>`](/lib/controllers/commit-detail-controller.js)
> > [`<CommitDetailView>`](/lib/views/commit-detail-controller.js)
> >
> > The workspace-center pane item that appears when looking at all the changes associated with a single commit that already exists in the current branch.
> >
> > > [`<MultiFilePatchController>`](/lib/controllers/multi-file-patch-controller.js)
> > > [`<MultiFilePatchView>`](/lib/views/multi-file-patch-view.js)
>
> > [`<IssueishDetailItem>`](/lib/items/issueish-detail-item.js)
> > [`<IssueishDetailContainer>`](/lib/containers/issueish-detail-container.js)
> > [`<IssueishDetailController>`](/lib/controllers/issueish-detail-controller.js)
> > [`<IssueDetailView>`](/lib/views/issue-detail-view.js)
> > [`<PullRequestDetailView>`](/lib/views/pr-detail-view.js)
> >
> > The workspace-center pane that displays information about a pull request or issue ("issueish", collectively) from github.com.
> >
> > > [`<IssueTimelineController>`](/lib/controllers/issue-timeline-controller.js)
> > > [`<IssueishTimelineView>`](/lib/views/issueish-timeline-view.js)
> > >
> > > Render "timeline events" (comments, label additions or removals, assignments...) related to an issue.
> >
> > > [`<PrTimelineController>`](/lib/controllers/pr-timeline-controller.js)
> > > [`<IssueishTimelineView>`](/lib/views/issueish-timeline-view.js)
> > >
> > > Render "timeline events" related to a pull request.
> >
> > > [`<PrStatusesView>`](/lib/views/pr-statuses-view.js)
> > >
> > > Display the current build state of a pull request in detail, including a "donut chart" and links to individual build results.
> >
> > > [`<PrCommitsView>`](/lib/views/pr-commits-view.js)
> > > [`<PrCommitView>`](/lib/views/pr-commit-view.js)
> > >
> > > Enumerate the commits associated with a pull request.
> >
> > > [`<PullRequestChangedFilesContainer>`](/lib/containers/pr-changed-files-container.js)
> > >
> > > Fetch all reviews and comments for a pull request, group comments, and render them.
> > > [`<PullRequestReviewsContainer>`](/lib/containers/pr-reviews-container.js)
> > > [`<PullRequestReviewCommentsContainer>`](/lib/containers/pr-review-comments-container.js)
> > > [`<PullRequestReviewsController>`](lib/controllers/pr-reviews-controller.js)
> > > [`<PullRequestCommentsView>`](lib/views/pr-review-comments-view.js)
> > > [`<PullRequestCommentView>`](lib/views/pr-review-comments-view.js)
> > >
> > > Show all the changes, separated by files, introduced in a pull request.
> > >
> > > > [`<MultiFilePatchController>`](/lib/controllers/multi-file-patch-controller.js)
> > > > [`<MultiFilePatchView>`](/lib/views/multi-file-patch-view.js)
>
> > [`<InitDialog>`](/lib/views/init-dialog.js)
> > [`<CloneDialog>`](/lib/views/clone-dialog.js)
> > [`<OpenIssueishDialog>`](/lib/views/open-issueish-dialog.js)
> > [`<CredentialDialog>`](/lib/views/credential-dialog.js)
> >
> > Various dialog panels we use to (modally) collect information from users. Notably, the CredentialDialog is used for usernames, passwords, SSH key passwords, and GPG passphrases.
>
> > [`<RepositoryConflictController>`](/lib/controllers/repository-conflict-controller.js)
> >
> > Identifies TextEditors opened on files that git believes contain merge conflicts.
> >
> > > [`<EditorConflictController>`](/lib/controllers/editor-conflict-controller.js)
> > >
> > > Parses conflict regions from the buffer associated with a single TextEditor.
> > >
> > > > [`<ConflictController>`](/lib/controllers/conflict-controller.js)
> > > >
> > > > Creates TextEditor decorations related to one conflict region, including resolution controls.
>
> > [`<StatusBarTileController>`](/lib/controllers/status-bar-tile-controller.js)
> >
> > Add the git and GitHub-related tiles to Atom's status bar.
> >
> > > [`<BranchView>`](/lib/views/branch-view.js)
> > >
> > > The little widget that tells you what branch you're on.
> >
> > > [`<BranchMenuView>`](/lib/views/branch-menu-view.js)
> > >
> > > Menu that appears within a tooltip when you click the current branch which lets you switch or create branches.
> >
> > > [`<PushPullView>`](/lib/views/push-pull-view.js)
> > >
> > > Shows the relative position of your local `HEAD` to its upstream ("1 ahead", "2 behind"). Allows you to fetch, pull, or push.
> >
> > > [`<ChangedFilesCountView>`](/lib/views/changed-files-count-view.js)
> > >
> > > Displays the git logo and the number of changed files. Clicking it opens the git tab.
> >
> > > [`<GithubTileView>`](/lib/views/changed-files-count-view.js)
> > >
> > > Displays the GitHub logo. Clicking it opens the GitHub tab.



## `MultiFilePatchView` Atlas

> [`<MultiFilePatchView>`](/lib/views/multi-file-patch-view.js)
> > [`<AtomTextEditor>`](lib/atom/atom-text-editor.js)
> >
> > React wrapper of an [Atom TextEditor](https://atom.io/docs/api/latest/TextEditor). Each `MultiFilePatchView` contains one `AtomTextEditor`, regardless of the number of file patch.
> >
> > > [`<Gutter>`](lib/atom/gutter.js)
> > >
> > > React wrapper of Atom's [Gutter](https://atom.io/docs/api/latest/Gutter) class.
> >
> > > [`<MarkerLayer>`](lib/atom/marker-layer.js)
> > > >
> > > > React wrapper of Atom's [MarkerLayer](https://atom.io/docs/api/latest/MarkerLayer) class.
> > > >
> > > > [`<Marker>`](lib/atom/marker.js)
> > > >
> > > > React wrapper of Atom's [DisplayMarker](https://atom.io/docs/api/latest/DisplayMarker) class.
> > > >
> > > > > [`<Decoration>`](lib/atom/decoration.js)
> > > > >
> > > > > React wrapper of Atom's [Decoration](https://atom.io/docs/api/latest/Decoration) class.
> > > > >
> > > > > > [`<FilePatchHeaderView>`](lib/views/file-patch-header-view.js)
> > > > > >
> > > > > > Header above each file patch. Handles file patch level operations (e.g. discard change, stage/unstage, jump to file, expand/collapse file patch, etc.)
> > > > >
> > > > > > [`<HunkHeaderView>`](lib/views/hunk-header-view.js)
> > > > > >
> > > > > > Header above each hunk. Handles more granular stage/unstage operation (per hunk or per line).
