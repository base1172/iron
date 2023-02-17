The obligation attribution machinery has its own functional-test
setup, which this following bit of script invokes.  This command has
no need to talk to the server, but we do use start_test to set
[$IRON_CONFIG], which is needed because the [hg manifest] command in
[hg/hg.ml] calls the [hgrc] function which accesses the env var.

  $ source ./bin/setup-script
  $ start_test

  $ for f in ./lib/obligations/tests/* ; do
  > if [ -d "$f" ] ; then
  >   ./lib/obligations/run-test "$f"
  >   fi
  > done

Should output nothing.
