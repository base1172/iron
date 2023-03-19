Slurp in the common setup code for the rebase tests:
  $ source ./bin/setup-script
  $ source ./lib/test-rebase-preface.sh &> /dev/null

Make a rebase that succeeds, but produces a file with conflicts.
We'll move root's f1.txt to one that conflicts with feature's f1.txt.

  $ cd "$remote_repo_dir"
  $ hg up -q -r "$r0"
  $ cat > f1.txt <<EOF
  > a
  > base-conflicts-with-feature-insert
  > b
  > c
  > EOF
  $ hg commit -q -m base-feature-incompatible
  $ root_noncompat=$(hg tip --template={rev})

-- Test: merge fails and rebase produces a file with conflict markers:
  $ cd "$local_repo_dir"
  $ (rb_diamond "$r0" "$root_noncompat" "$feature_tip" \
  >             -fake-valid-obligations -fake-valid-obligations || true ) |& stabilize_output
  Checking cleanliness of local repo ... done.
  Pulling root/test-feature in local repo ... done.
  Pulling {REVISION 4} in local repo ... done.
  Updating local repo to root/test-feature ... done.
  Merging with {REVISION 4}.
  merging f1.txt
  merge: warning: conflicts during merge
  merging f1.txt failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  Pushing root/test-feature to $TESTCASE_ROOT/remote ... done.

  $ cat f1.txt | stabilize_output
  a
  <<<<<<< old tip: root/test-feature [{REVISION 1}]
  feature-insert
  ||||||| old base: {REVISION 0}
  =======
  base-conflicts-with-feature-insert
  >>>>>>> new base: root [{REVISION 4}]
  b
  c
