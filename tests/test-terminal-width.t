  $ source ./bin/setup-script
  $ setup_test
  $ unset TERM COLUMNS
  $ fe.exe internal terminal-width
  90
  $ TERM=xterm fe.exe internal terminal-width
  80
  $ TERM=xterm COLUMNS=42 fe.exe internal terminal-width
  42
  $ TERM=foo fe.exe internal terminal-width
  90
