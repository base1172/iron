Start test. 

  $ source ./bin/setup-script
  $ start_test

  $ setup_repo_and_root file
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root
  $ fe create root/child -desc child
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root/child
  $ fe up root
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root
  $ fe up root/child
  $ hg bookmarks --list . --template '{activebookmark}\n'
  root/child
 
