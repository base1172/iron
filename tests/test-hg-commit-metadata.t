Setup

  $ source ./bin/setup-script
  $ setup_test

Create hg repo.

  $ mkdir repo
  $ cd repo
  $ hg init
  $ echo "hello world" > hello_world.txt
  $ hg add hello_world.txt

Test committing with metadata in the [extra] field

  $ hg --config='extensions.commitextras=' commit -m "init" --extra a=hello --extra b=world
  $ hg log -r . --debug | grep extra | matches "a=hello"
  $ hg log -r . --debug | grep extra | matches "b=world"
