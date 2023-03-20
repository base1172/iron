Start test.

  $ source ./bin/setup-script
  $ start_test

Create hg repo.

  $ setup_repo_and_root file
  $ touch file2; hg add file2; hg commit --message 'file2' file2
  $ touch file3; hg add file3; hg commit --message 'file3' file3
  $ feature_to_server root

The log is in reverse-chronological order.

  $ fe log root -- --template='{rev}\n'
  2
  1

The log is human readable.

  $ fe log root | sanitize_output
  changeset:   2:{ELIDED}    
  bookmark:    root
  tag:         tip
  user:        unix-login-for-testing
  date:        {ELIDED}                            
  summary:     file3
  
  changeset:   1:{ELIDED}    
  user:        unix-login-for-testing
  date:        {ELIDED}                            
  summary:     file2
  
