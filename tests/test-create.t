Start test.

  $ source ./bin/setup-script
  $ start_test

Create hg repo.

  $ mkdir repo
  $ cd repo
  $ hg init
  $ echo "c1" > f1.ml
  $ hg add f1.ml

Don't commit yet -- we'd like to observe create failing on an unclean repo:

  $ fe.exe create root -description 'root' -remote-repo-path $(pwd) |& matches "repository is not clean"
  [1]

OK, now commit to get repo into a clean state:

  $ hg commit -m "init"

Missing remote-repo-path.  At one point, there was a bug where this would
create an empty feature directory in the persistent state.

  $ fe.exe create root -description 'root'
  Must supply -remote-repo-path when creating a root feature.
  [1]
  $ fe-server stop
  $ fe-server start

Successful creation of a feature.

  $ fe.exe tools feature-exists root
  false
  $ fe.exe create root -description 'root' -remote-repo-path $(pwd) -property prop1=value1 -property prop2=value2
  $ fe.exe tools feature-exists root
  true
  $ fe.exe list
  |------------------------------------|
  | feature |   lines | next step      |
  |---------+---------+----------------|
  | root    | pending | wait for hydra |
  |------------------------------------|
  $ fe.exe show | grep prop | single_space
  | prop1 | value1 |
  | prop2 | value2 |

Can't create a dupe feature.

  $ fe.exe create root -description 'root-again' -remote-repo-path $(pwd)
  Repository already contains a bookmark named [root].
  [1]
  $ fe.exe create root -no-bookmark -description 'root-again' -remote-repo-path $(pwd) |& matches "feature already exists"
  [1]

Persistence.

  $ fe-server stop
  $ fe.exe tools feature-exists root |& matches "The Iron server is down unexpectedly." >/dev/null
  [1]
  $ fe-server start
  $ fe.exe list
  |------------------------------------|
  | feature |   lines | next step      |
  |---------+---------+----------------|
  | root    | pending | wait for hydra |
  |------------------------------------|
  $ fe.exe show | grep prop | single_space
  | prop1 | value1 |
  | prop2 | value2 |

Add files and run hydra:

  $ feature_to_server root
  $ fe.exe list
  |--------------------------------|
  | feature | lines | next step    |
  |---------+-------+--------------|
  | root    | error | fix problems |
  |--------------------------------|

Cannot make child off known-bad base:

  $ fe.exe create root/child -description 'child' 2>&1 | sed --regexp-extended -e 's/invalid base revision [0-9a-f]+/invalid base revision {REVISION}/'
  (error
   (create-feature
    ("invalid base revision {REVISION}"
     ("revision is not CR clean -- consider using -allow-non-cr-clean-base"
      "obligations are invalid"))))
  [1]

Fix root:

  $ BOOKMARK=root fe.exe internal hydra -fake-valid-obligations; hg -q update -r root
  $ fe.exe list
  |-----------------------------|
  | feature | lines | next step |
  |---------+-------+-----------|
  | root    |     0 | add code  |
  |-----------------------------|

Cannot create when Create_child has been locked on parent.

  $ fe.exe lock -create-child root -reason 'testing'
  $ fe.exe create root/child -description 'child' \
  >     |& matches "feature lock is locked.*(feature_path root) (lock_name Create_child).*"
  [1]
  $ fe.exe unlock -create-child root

Make the child:

  $ fe.exe create root/child -description 'child'
  $ fe.exe list
  |-----------------------------|
  | feature | lines | next step |
  |---------+-------+-----------|
  | root    |     0 | add code  |
  |-----------------------------|
  $ fe.exe list root
  |------------------------------------|
  | feature |   lines | next step      |
  |---------+---------+----------------|
  | root    |       0 | add code       |
  |   child | pending | wait for hydra |
  |------------------------------------|

Persistence.

  $ fe-server stop
  $ fe-server start
  $ fe.exe list
  |-----------------------------|
  | feature | lines | next step |
  |---------+-------+-----------|
  | root    |     0 | add code  |
  |-----------------------------|
  $ fe.exe list root
  |------------------------------------|
  | feature |   lines | next step      |
  |---------+---------+----------------|
  | root    |       0 | add code       |
  |   child | pending | wait for hydra |
  |------------------------------------|

Non cr-clean base.

  $ hg -q up root/child
  $ cat > f2.ml <<EOF
  > (* $CR user1: cr1 *)
  > EOF
  $ hg add f2.ml
  $ hg -q commit -m '0'
  $ feature_to_server root/child -fake-valid
  $ fe.exe create root/child/cr -description '' 2>&1 | sed --regexp-extended -e 's/invalid base revision [0-9a-f]+/invalid base revision {REVISION}/'
  (error
   (create-feature
    ("invalid base revision {REVISION}"
     "revision is not CR clean -- consider using -allow-non-cr-clean-base")))
  [1]
  $ fe.exe create root/child/cr -description '' -allow-non-cr-clean-base
  $ fe.exe list root/child
  |------------------------------------|
  | feature |   lines | next step      |
  |---------+---------+----------------|
  | root    |         |                |
  |   child |       2 | CRs            |
  |     cr  | pending | wait for hydra |
  |------------------------------------|

[fe.exe create -add-whole] adding an owner as a whole-feature reviewer.

  $ fe.exe create root/child2 -desc child -add-whole-feature-reviewers unix-login-for-testing,user1

Confirm we're still located in root/child feature, despite having just created root/child2
  $ fe.exe show -feature-path
  root/child

Confirm whole-feature-reviewers for root/child2
  $ fe.exe show root/child2 -whole-feature-reviewers
  (unix-login-for-testing user1)

If the -description flag is missing, your editor pops up prompting you
for one.  (We test this by setting up a silly one-off editor.)
  $ export EDITOR=$IRON_TEST_ROOT/one-off-editor
  $ echo >$EDITOR \
  >   'sed -i -r "s/WRITE ME.*/This feature adds fancy fanciness./" $1'
  $ chmod u+x $EDITOR

  $ fe.exe create root/child3 -interactive true >/dev/null
  $ fe.exe description show root/child3
  This feature adds fancy fanciness.

Here is the text you see when your editor pops up.  (We test this by
picking an editor that does nothing.)

  $ EDITOR=true fe.exe create root/child4
  $ fe.exe description show root/child4
  WRITE ME (replace with a description of root/child4)

If your editor fails, the feature is created with the default description.

  $ EDITOR=false fe.exe create root/child5 -interactive true >/dev/null
  ("Error editing text" (Error (Exit_non_zero 1)))
  [1]
  $ fe.exe description show root/child5
  WRITE ME (replace with a description of root/child5)
