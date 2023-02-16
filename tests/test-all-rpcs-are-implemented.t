  $ source ./bin/setup-script
  $ start_test

  $ diff -u \
  >    <(fe.exe internal rpc-to-server supported-by-client) \
  >    <(fe.exe internal rpc-to-server supported-by-server)

  $ diff -u \
  >    <(fe.exe internal command-rpc supported-by-iron-lib) \
  >    <(fe.exe internal command-rpc supported-by-command)

  $ diff -u \
  >    <(fe.exe internal command-rpc supported-by-iron-lib -names-only) \
  >    <(fe.exe internal command-rpc referenced-by-fe-file)
