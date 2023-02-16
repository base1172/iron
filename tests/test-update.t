Start test. 

  $ source ./bin/setup-script
  $ start_test

  $ setup_repo_and_root file
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root
  $ fe.exe create root/child -desc child
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root/child
  $ fe.exe up root
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root
  $ fe.exe up root/child
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root/child
 
