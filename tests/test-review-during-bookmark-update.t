Checking that we ask the worker for sufficiently many review edges that even if we change
reviewers or reviews during a bookmark update, we won't have troubles.

  $ source ./bin/setup-script
  $ start_test
  $ setup_repo_and_root a
  $ export rev0=$(hg log -r . --template '{node|short}')

Make sure we have no review managers, but there is a non empty review goal:

  $ fe change -remove-whole-feature-reviewers unix-login-for-testing
  $ fe enable-review
  $ feature_to_server root -fake-valid
  $ echo b > a
  $ hg commit -m b
  $ export rev1=$(hg log -r . --template '{node|short}')
  $ feature_to_server root -fake-valid
  $ ls $IRON_BASEDIR/export/features/*/review-managers

Now during the next bookmark update, add a reviewer:

  $ echo c > a
  $ hg commit -m c
  $ export rev2=$(hg log -r . --template '{node|short}')
  $ feature_to_server root -fake-valid -run-between-rpcs '
  >  fe change root -add-whole-feature-reviewer user
  >  IRON_USER=user fe tools mark-fully-reviewed root'

And this reviewer should have a normal review, not a forget followed
by a review from scratch:

  $ IRON_USER=user fe session diff | fe internal remove-color | sub ${rev0} {BASE_HASH} | sub ${rev1} {OLD_TIP} | sub ${rev2} {NEW_TIP}
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ a @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  scrutiny level10
  base {BASE_HASH} | old tip {OLD_TIP} | new tip {NEW_TIP}
  @@@@@@@@ old tip 1,2 new tip 1,2 @@@@@@@@
  -|b
  +|c


Second tricky case: review to the review goal while the update bookmark of a rebase
is pending.

  $ fe create root/child -d 'child' -base 0
  $ fe enable-review
  $ echo child1 > a
  $ hg commit -q -m child
  $ export rev_child=$(hg log -r . --template '{node|short}')
  $ feature_to_server root/child -fake-valid

Now that the review goal is non empty, rebase and review before the update-bookmark
comes in:

  $ fe rebase |& matches "merging a failed"
  $ echo child2 > a; hg commit -q -m child
  $ export rev_child2=$(hg log -r . --template '{node|short}')
  $ feature_to_server root/child -fake-valid -run-between-rpcs '
  >  IRON_USER=unix-login-for-testing fe tools mark-fully-reviewed root/child'

And one would expect a conflict diff4, instead of a forget and a review from scratch:

  $ fe session diff | fe internal remove-color | sub ${rev0} {OLD_BASE} | sub ${rev2} {NEW_BASE} | sub ${rev_child} {OLD_TIP} | sub ${rev_child2} {NEW_TIP}
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ a @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  scrutiny level10
  old base {OLD_BASE} | old tip {OLD_TIP} | new base {NEW_BASE} | new tip {NEW_TIP}
  @@@@@@@@ View : feature-ddiff @@@@@@@@
  @@@@@@@@ -- old base 1,3 old tip 1,3 @@@@@@@@
  @@@@@@@@ ++ new base 1,3 new tip 1,3 @@@@@@@@
  ---|a
  --+|child1
  ++-|c
  +++|child2
