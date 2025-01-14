This test ensures an important behavior for feature explorer, namely
that [!r] is able to mark a file in an empty session, even if the
feature tip has moved since the session was created.

  $ source ./bin/setup-script
  $ start_test
  $ setup_repo_and_root file
  $ echo change >file
  $ hg com -m change
  $ fe enable
  $ feature_to_server root -fake-valid
  $ sid=$(fe session show -id)

Advance the feature.

  $ echo change2 >file
  $ hg com -m change2
  $ feature_to_server root -fake-valid
  $ fe show root | stabilize_output
  root
  ====
  root
  
  |-------------------------------------------------|
  | attribute              | value                  |
  |------------------------+------------------------|
  | next step              | review                 |
  | owner                  | unix-login-for-testing |
  | whole-feature reviewer | unix-login-for-testing |
  | seconder               | not seconded           |
  | review is enabled      | true                   |
  | reviewing              | unix-login-for-testing |
  | is permanent           | true                   |
  | tip                    | {REVISION 2}           |
  | base                   | {REVISION 0}           |
  |-------------------------------------------------|
  
  |---------------------------------|
  | user                   | review |
  |------------------------+--------|
  | unix-login-for-testing |      2 |
  |---------------------------------|

Even though the feature has advanced and the session is empty, we can
still mark a file in it.

  $ fe session mark-file -session-id $sid root file

But then we still have to review the subsequent diff.

  $ fe session show | stabilize_output
  Reviewing root from {REVISION 0} to {REVISION 2}.
  1 files to review: 2 lines total
     [ ] 2 file
