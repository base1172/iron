Start test. 

  $ source ./bin/setup-script
  $ start_test

  $ setup_repo_and_root f1.txt
  $ hg book | grep -qF "* root"

Test that 'fe create' fails if the bookmark update failed, at least in
the particular case where the failure was due to a permissions
problem.

  $ hg init remote
  $ cd remote
  $ echo a > a; hg add a; hg commit -m a
  $ hg book just-to-create-bookmark-file
  $ cd ..
  $ hg clone -q remote local
  $ rm remote/.hg/bookmarks
  $ mkdir remote/.hg/bookmarks
  $ cd local
  $ fe create root2 -description root2 -remote-repo-path $(realpath ../remote)
  ("[hg push] failed"
   ((stdout
     ("pushing to $TESTCASE_ROOT/repo/remote"
      "searching for changes" ""))
    (stderr
     ("abort: Is a directory: '$TESTCASE_ROOT/repo/remote/.hg/bookmarks'"
      ""))
    (exit_status (Error (Exit_non_zero 255)))))
  [1]
