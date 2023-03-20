Regression test to make sure we don't extend users brain with implicitly
reviewed diff4s too eagerly, which causes an unnecessary number of revisions in
[need-diff4s-starting-from]

  $ export NUM=5

  $ source ./bin/setup-script
  $ start_test
  $ setup_repo_and_root $(for i in $(seq 1 ${NUM}) ; do echo "f${i}" ; done)

Put some contents in the users' brain for each file.

  $ for i in $(seq 1 ${NUM}) ; do
  >   echo base >"f${i}"
  > done
  > hg commit -m base
  > feature_to_server root -fake-valid

  $ fe tools mark-fully-reviewed root
  $ fe internal need-diff4s-starting-from | stabilize_output
  ((((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 1}))))
    (unix-login-for-testing)))

Now, create a line of commits with changes to each file.  We used to have a bug
causing the brain to be extended for each file up to the most recent commit
where its contents is the same than in the brain.  Check that this is no longer
the case.

  $ for i in $(seq 1 ${NUM}) ; do
  >   echo change >"f${i}"
  >   hg commit -m change
  >   feature_to_server root -fake-valid
  > done

  $ fe show -omit-attribute-table
  root
  ====
  root
  
  |---------------------------------------------|
  | user                   | review | completed |
  |------------------------+--------+-----------|
  | unix-login-for-testing |     10 |        10 |
  |---------------------------------------------|

  $ fe internal need-diff4s-starting-from | stabilize_output
  ((((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 6}))))
    (unix-login-for-testing))
   (((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 1}))))
    (unix-login-for-testing)))
