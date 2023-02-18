  $ source ./bin/setup-script
  $ start_test

Create a conflict where the child changes a file while the base deletes it:

  $ setup_repo_and_root file
  $ feature_to_server root -fake-valid
  $ fe create root/child -d ''
  $ echo changed > file
  $ hg commit -m child
  $ feature_to_server root/child -fake-valid
  $ fe tools mark-fully-reviewed root/child

  $ hg -q update -r root
  $ hg rm file
  $ hg -q commit -m root
  $ feature_to_server root -fake-valid


The rebase keeps the old-tip as-is, with no conflict markers.

  $ fe show root/child -base | sanitize_output
  {ELIDED}

  $ fe rebase root/child |& matches "file 'file' was deleted in other \[merge rev\] but was modified in local \[working copy\]"

  $ fe show root/child -base | sanitize_output
  {ELIDED}
  $ feature_to_server root/child -fake-valid

And Iron shows the conflict resolution during review:

  $ fe session diff root/child | fe internal remove-color | sanitize_output
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ file @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  old base file      = file
  new base file      = <absent>
  old & new tip file = file
  old base {ELIDED}     | old tip {ELIDED}     | new base {ELIDED}     | new tip {ELIDED}    
  _
  | @@@@@@@@ Hunk 1/2 @@@@@@@@
  | @@@@@@@@ A change present only in the new-base was dropped @@@@@@@@
  | @@@@@@@@ new base 1,2 old base, old tip, new tip 1,5 @@@@@@@@
  | -|<absent>
  | +|file        = file
  | +|scrutiny    = level10
  | +|owner       = file-owner
  | +|reviewed by = None
  |_
  _
  | @@@@@@@@ Hunk 2/2 @@@@@@@@
  | @@@@@@@@ View : feature-ddiff @@@@@@@@
  | @@@@@@@@ A base change was dropped in favor of a feature change @@@@@@@@
  | @@@@@@@@ -- old base 1,3 new tip, old tip 1,2 @@@@@@@@
  | @@@@@@@@ ++ new base 1,3 old tip, new tip 1,2 @@@@@@@@
  | ---|file
  | --+|changed
  | +++|changed
  |_
