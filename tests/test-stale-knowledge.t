  $ source ./bin/setup-script
  $ start_test

  $ setup_repo_and_root a
  $ fe create root/feature -d root/feature
  $ touch b; hg add b; hg commit -m b
  $ fe enable
  $ feature_to_server root/feature -fake-valid
  $ fe session show | sanitize_output
  Reviewing root/feature to {ELIDED}    .
  1 files to review: 1 lines total
     [ ] 1 b
  $ fe session mark-file root/feature b
  $ fe session show |& matches "reviewer is up to date"
  [1]
  $ hg rm b
  $ hg commit -m b2
  $ feature_to_server root/feature -fake-valid
  $ fe session show | sanitize_output
  Reviewing root/feature to {ELIDED}    .
  1 files to review: 1 lines total
     [ ] 1 b
  $ fe session diff | fe internal remove-color | sanitize_output
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ b @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  base file    = <absent>
  old tip file = b
  new tip file = <absent>
  base {ELIDED}     | old tip {ELIDED}     | new tip {ELIDED}    
  @@@@@@@@ A change in the feature was reverted @@@@@@@@
  @@@@@@@@ old tip 1,5 base, new tip 1,2 @@@@@@@@
  -|file        = b
  -|scrutiny    = level10
  -|owner       = file-owner
  -|reviewed by = None
  +|<absent>
