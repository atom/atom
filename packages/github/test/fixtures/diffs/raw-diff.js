import dedent from 'dedent-js';

const rawDiff = dedent`
  diff --git file.txt file.txt
  index 83db48f..bf269f4 100644
  --- file.txt
  +++ file.txt
  @@ -1,3 +1,3 @@ class Thing {
   line1
  -line2
  +new line
   line3
`;

const rawDiffWithPathPrefix = dedent`
  diff --git a/bad/path.txt b/bad/path.txt
  index af607bb..cfac420 100644
  --- a/bad/path.txt
  +++ b/bad/path.txt
  @@ -1,2 +1,3 @@
    line0
  -line1
  +line1.5
  +line2
`;

const rawDeletionDiff = dedent`
  diff --git a/deleted b/deleted
  deleted file mode 100644
  index 0065a01..0000000
  --- a/deleted
  +++ /dev/null
  @@ -1,4 +0,0 @@
  -this
  -file
  -was
  -deleted
`

const rawAdditionDiff = dedent`
  diff --git a/added b/added
  new file mode 100644
  index 0000000..4cb29ea
  --- /dev/null
  +++ b/added
  @@ -0,0 +1,3 @@
  +one
  +two
  +three
`

export {rawDiff, rawDiffWithPathPrefix, rawDeletionDiff, rawAdditionDiff};
