Start test.

  $ source ./bin/setup-script
  $ start_test

Create hg repo.

  $ mkdir repo
  $ cd repo
  $ hg init
  $ touch file
  $ hg add file
  $ hg com -m file
  $ echo hello >file
  $ hg com -m change

Create feature.

  $ remote=$(pwd)
  $ fe create root -base 0 -tip 1 -description 'root' -remote-repo-path $remote
  $ feature_to_server root -fake-valid-obligations

Show it.

  $ fe show root | sanitize_output
  root
  ====
  root
  
  |-------------------------------------------------|
  | attribute              | value                  |
  |------------------------+------------------------|
  | next step              | enable-review          |
  | owner                  | unix-login-for-testing |
  | whole-feature reviewer | unix-login-for-testing |
  | seconder               | not seconded           |
  | review is enabled      | false                  |
  | CRs are enabled        | true                   |
  | reviewing              | unix-login-for-testing |
  | is permanent           | false                  |
  | tip                    | {ELIDED}               |
  | base                   | {ELIDED}               |
  |-------------------------------------------------|
  
  |---------------------------------|
  | user                   | review |
  |------------------------+--------|
  | unix-login-for-testing |      1 |
  |---------------------------------|
