Start test.

  $ source ./bin/setup-script
  $ start_test

Setup repo.

  $ setup_repo_and_root a
  $ feature_to_server root -fake-valid
  $ rev0=$(hg log -r . --template={node})
  $ echo change >a; hg commit -m 'change'
  $ rev1=$(hg log -r . --template={node})
  $ feature_to_server root -fake-valid
  $ fe enable

Can't infer the feature if the bookmark isn't there.

  $ create_local_clone
  $ hg book --delete root
  $ fe review |& matches 'could not determine feature you want to use'
  [1]

Review automatically pulls and updates to the bookmark.

  $ do_fe_review
  $ hg book | sanitize_output
   * root                      1:{ELIDED}    

If the repo isn't clean, the review succeeds iff the bookmark is active.

  $ touch z
  $ do_fe_review
  $ hg up -q -r $rev1
  $ do_fe_review | matches 'needs to \[hg update\] but won'\''t.*hg repository is not clean'

Review pulls and updates to the necessary rev.

  $ create_local_clone -r $rev0
  $ hg log -r $rev1 |& matches 'unknown revision'
  [255]
  $ do_fe_review
  $ hg log -r $rev1 >/dev/null
  $ hg book | sanitize_output
   * root                      1:{ELIDED}    

Review automatically updates if the bookmark is current but not active.

  $ create_local_clone
  $ hg book -f -r $rev0 root
  $ hg up -q -r root
  $ hg pull -q -r root
  $ cat .hg/bookmarks.current
  root (no-eol)
  $ hg active-bookmark
  [1]
  $ parent_is $rev0
  $ do_fe_review
  $ parent_is $rev1

If the repo isn't clean, and Iron needs to pull
the error message includes the cleanliness error

  $ create_local_clone -r $rev0
  $ hg log -r $rev1 |& matches 'unknown revision'
  [255]
  $ touch z
  $ do_fe_review | matches 'needs to pull but won'\''t.*hg repository is not clean'

