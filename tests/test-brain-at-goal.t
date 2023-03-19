  $ source ./bin/setup-script
  $ start_test
  $ setup_repo_and_root file
  $ echo change >file; hg com -m change
  $ feature_to_server root -fake-valid
  $ fe enable

Mark the user.

  $ fe tools mark-fully-reviewed root -for unix-login-for-testing

Add new commits, leaving the feature unchanged.

  $ echo change2 >file; hg com -m change2
  $ feature_to_server root -fake-valid
  $ echo change >file; hg com -m change
  $ feature_to_server root -fake-valid

Make sure the diff4s needed are at the review goal.

  $ fe show -base | stabilize_output
  {REVISION 0}
  $ fe show -tip | stabilize_output
  {REVISION 3}
  $ fe internal need-diff4s-starting-from | stabilize_output
  ((((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 3}))))
    (unix-login-for-testing)))

Start a session.

  $ touch file2; hg add file2; hg com -m file2
  $ echo change2 >file; hg com -m change2
  $ feature_to_server root -fake-valid
  $ fe session mark-file root file
  $ fe session show | stabilize_output
  Reviewing root from {REVISION 0} to {REVISION 5}.
  1 files to review (1 already reviewed): 3 lines total
     [X] 2 file
     [ ] 1 file2

Extend the feature with a no-op.

  $ echo change  >file; hg com -m change
  $ echo change2 >file; hg com -m change2
  $ feature_to_server root -fake-valid

Finish the session.

  $ fe session mark-file root file2

The reviewer brain has been advanced to the goal.

  $ fe show -tip | stabilize_output
  {REVISION 7}
  $ fe internal need-diff4s-starting-from | stabilize_output
  ((((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 5}))))
    (unix-login-for-testing))
   (((base
      ((human_readable ())
       (node_hash {REVISION 0})))
     (tip
      ((human_readable ())
       (node_hash {REVISION 7}))))
    (file-owner unix-login-for-testing)))
