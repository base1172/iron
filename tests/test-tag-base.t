Start test.

  $ source ./bin/setup-script
  $ start_test

Create hg repo.

  $ setup_repo_and_root file
  $ echo change >file; hg com -m 'change'
  $ feature_to_server root -fake-valid

Tag the root tip.

  $ hg up -q -r 0  # so that tagging doesn't change [root]
  $ export base_hash=$(hg log -r . --template '{node|short}')
  $ hg tag -f -r root 'root-111.11+24'
  $ hg tag -r root 'root-111.12'
  $ export root_hash=$(hg log -r root --template '{node|short}')
  $ hg log -r root '--template={tags}\n'
  root-111.11+24 root-111.12

Create a child, and it has a nice name for its base.

  $ fe create root/child -desc child
  $ feature_to_server root/child -fake-valid
  $ fe show | sed -e "s/\[${root_hash}\]/[  {ELIDED}  ]/g"
  root/child
  ==========
  child
  
  |-----------------------------------------------------|
  | attribute              | value                      |
  |------------------------+----------------------------|
  | next step              | add code                   |
  | owner                  | unix-login-for-testing     |
  | whole-feature reviewer | unix-login-for-testing     |
  | seconder               | not seconded               |
  | review is enabled      | false                      |
  | CRs are enabled        | true                       |
  | reviewing              | unix-login-for-testing     |
  | is permanent           | false                      |
  | tip                    | root-111.12 [  {ELIDED}  ] |
  | base                   | root-111.12 [  {ELIDED}  ] |
  |-----------------------------------------------------|

The base gets a nice name even if the rev is not present when [fe create] starts.
FIXME: This test fails because we don't have jane street's iron_bookmark_manipulation.py extension

  $ cd ..
  $ hg clone -q -r ${base_hash} repo repo2
  $ cd repo2
  $ hg log -r ${root_hash} |& matches "unknown revision"
  [255]
  $ IRON_OPTIONS='((workspaces false))' fe create root/child2 -desc child2
  $ feature_to_server root/child2 -fake-valid
  $ fe show | sed -e "s/\[${root_hash}\]/[  {ELIDED}  ]/g"
  root/child2
  ===========
  child2
  
  |-----------------------------------------------------|
  | attribute              | value                      |
  |------------------------+----------------------------|
  | next step              | add code                   |
  | owner                  | unix-login-for-testing     |
  | whole-feature reviewer | unix-login-for-testing     |
  | seconder               | not seconded               |
  | review is enabled      | false                      |
  | CRs are enabled        | true                       |
  | reviewing              | unix-login-for-testing     |
  | is permanent           | false                      |
  | tip                    | root-111.12 [  {ELIDED}  ] |
  | base                   | root-111.12 [  {ELIDED}  ] |
  |-----------------------------------------------------|
