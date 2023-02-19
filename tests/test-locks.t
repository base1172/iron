Start test.

  $ source ./bin/setup-script
  $ start_test

Create a feature.

  $ setup_repo_and_root file
  $ feature_to_server root -fake-valid

Show locks.

  $ fe show -what-is-locked
  ()
  $ fe is-unlocked |& matches "Must specify which locks to check."
  [1]
  $ fe is-unlocked -all-locks
  $ fe is-unlocked -rebase
  $ fe is-unlocked -release
  $ fe is-unlocked -release-into
  $ fe is-unlocked -rebase -release -release-into

Take a few locks.

  $ fe lock -rebase -release -release-into -reason 'test'
  $ fe show -what-is-locked | stabilize_timestamps
  ((Rebase
    (((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
   (Release
    (((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
   (Release_into
    (((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false)))))
  $ fe is-unlocked -all-locks |& stabilize_timestamps
  (locked
   ((Rebase
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
    (Release
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
    (Release_into
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))))
  [1]
  $ fe is-unlocked -rebase |& stabilize_timestamps
  (locked
   ((Rebase
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))))
  [1]
  $ fe is-unlocked -rebase -release -release-into |& stabilize_timestamps
  (locked
   ((Rebase
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
    (Release
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
    (Release_into
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))))
  [1]

Check that a different user can concurrently lock.

  $ fe lock -rebase -reason 'test' -for user1

And the user owning the lock can amend a lock.

  $ fe lock -release -reason 'blah'
  $ fe show -what-is-locked | stabilize_timestamps
  ((Rebase
    (((by user1) (reason test) (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm))
      (is_permanent false))
     ((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
   (Release
    (((by unix-login-for-testing) (reason blah)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
   (Release_into
    (((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false)))))
  $ fe show | stabilize_output
  root
  ====
  root
  
  |---------------------------------------------------|
  | attribute                | value                  |
  |--------------------------+------------------------|
  | next step                | add code               |
  | owner                    | unix-login-for-testing |
  | whole-feature reviewer   | unix-login-for-testing |
  | seconder                 | not seconded           |
  | review is enabled        | false                  |
  | CRs are enabled          | true                   |
  | reviewing                | unix-login-for-testing |
  | is permanent             | true                   |
  | tip                      | {REVISION 0}           |
  | base                     | {REVISION 0}           |
  | locks                    |                        |
  |   rebase locked by       | unix-login-for-testing |
  |   rebase locked by       | user1                  |
  |   release locked by      | unix-login-for-testing |
  |   release-into locked by | unix-login-for-testing |
  |---------------------------------------------------|

  $ fe show -show-lock-reasons | stabilize_output
  root
  ====
  root
  
  |---------------------------------------------------------|
  | attribute                | value                        |
  |--------------------------+------------------------------|
  | next step                | add code                     |
  | owner                    | unix-login-for-testing       |
  | whole-feature reviewer   | unix-login-for-testing       |
  | seconder                 | not seconded                 |
  | review is enabled        | false                        |
  | CRs are enabled          | true                         |
  | reviewing                | unix-login-for-testing       |
  | is permanent             | true                         |
  | tip                      | {REVISION 0}                 |
  | base                     | {REVISION 0}                 |
  | locks                    |                              |
  |   rebase locked by       | unix-login-for-testing: test |
  |   rebase locked by       | user1: test                  |
  |   release locked by      | unix-login-for-testing: blah |
  |   release-into locked by | unix-login-for-testing: test |
  |---------------------------------------------------------|

One user unlocking doesn't unlock another's.

  $ fe unlock -rebase
  $ fe show -what-is-locked | stabilize_timestamps
  ((Rebase
    (((by user1) (reason test) (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm))
      (is_permanent false))))
   (Release
    (((by unix-login-for-testing) (reason blah)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false))))
   (Release_into
    (((by unix-login-for-testing) (reason test)
      (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent false)))))

Must unlock at least one lock.

  $ fe unlock |& matches "Must supply at least one lock to unlock."
  [1]

Check that it is an error to unlock if it is not locked.

  $ fe unlock -rebase |& matches "not locked"
  [1]

A user can lock a feature in a permanent fashion.

  $ fe lock -release-into -reason test -permanent
  $ fe is-unlocked -release-into |& stabilize_timestamps
  (locked
   ((Release_into
     (((by unix-login-for-testing) (reason test)
       (at (yyyy-mm-dd hh:mm:ss.xxxxxxxxx+hh:mm)) (is_permanent true))))))
  [1]

When that happens, a special switch is required to unlock.

  $ fe unlock -release-into \
  >  |& matches "This lock is permanent -- consider using -even-if-permanent"
  [1]
  $ fe unlock -release-into -even-if-permanent
  $ fe is-unlocked -release-into

Locks for rebase, release into and rebase are tested in test-release, and test-rebase
