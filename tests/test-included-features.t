Start test.

  $ source ./bin/setup-script
  $ start_test

Make a repo with root and child features.

  $ hg init repo
  $ cd repo
  $ remote=$PWD
  $ touch file; hg add file; hg com -m 0

  $ fe create root -remote $remote -d root
  $ echo 1 > file; hg commit -m 1
  $ fe enable
  $ feature_to_server root -fake-valid
  $ fe change -add-whole-feature-reviewers user1
  $ IRON_USER=user1 fe second

  $ fe create root/app       -d "description of app"
  $ echo 2 > file; hg commit -m 2
  $ fe enable
  $ feature_to_server root/app -fake-valid
  $ fe change -add-whole-feature-reviewers user1
  $ IRON_USER=user1 fe second

  $ fe create root/app/child -d "description of child"
  $ echo 3 > file; hg commit -m 3
  $ fe enable
  $ feature_to_server root/app/child -fake-valid
  $ fe change -add-whole-feature-reviewers user1
  $ IRON_USER=user1 fe second

  $ fe create root/app/child/nested -d "\
  > Description of nested child.
  > With multiple lines.
  > "
  $ echo 4 > file; hg commit -m 4
  $ fe enable
  $ feature_to_server root/app/child/nested -fake-valid
  $ fe change -add-whole-feature-reviewers user1
  $ IRON_USER=user1 fe second

Release.

  $ for f in root root/app root/app/child root/app/child/nested; do
  >     fe tools mark-fully-reviewed $f -for all -reason reason
  > done
  $ make_releasable root/app/child/nested

  $ fe diff root/app/child/nested | fe internal remove-color | stabilize_output root/app/child/nested
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ file @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  scrutiny level10
  base {REVISION 3} | tip {REVISION 4}
  @@@@@@@@ base 1,2 tip 1,2 @@@@@@@@
  -|3
  +|4

Finally, the feature is releasable.

  $ fe is-releasable root/app/child/nested
  $ nested_child_base=$(fe show root/app/child/nested -base)
  $ nested_child_tip=$(fe show root/app/child/nested -tip)

  $ fe release root/app/child/nested
  $ feature_to_server root/app/child -fake-valid

Show the parent.

  $ fe show root/app/child -show-included-feature-details | stabilize_output root/app/child
  root/app/child
  ==============
  description of child
  
  |---------------------------------------------------------|
  | attribute               | value                         |
  |-------------------------+-------------------------------|
  | next step               | release                       |
  | owner                   | unix-login-for-testing        |
  | whole-feature reviewers | unix-login-for-testing, user1 |
  | seconder                | user1                         |
  | review is enabled       | true                          |
  | reviewing               | all                           |
  | is permanent            | false                         |
  | tip                     | {REVISION 4}                  |
  | base                    | {REVISION 2}                  |
  |---------------------------------------------------------|
  
  |-----------------------------------------------|
  | user                   | catch-up | completed |
  |------------------------+----------+-----------|
  | user1                  |        2 |         2 |
  | unix-login-for-testing |          |         2 |
  |-----------------------------------------------|
  
  Included features:
    root/app/child/nested
  
  root/app/child/nested
  =====================
  Description of nested child.
  With multiple lines.
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 3}                         |
  |----------------------------------------------------------------|

Release a feature with included features into a non root

  $ fe change -set-is-permanent true root
  $ fe change -set-is-permanent true root/app
  $ fe change -set-is-permanent true root/app/child
  $ make_releasable root/app/child
  $ fe release root/app/child
  $ feature_to_server root/app/child -fake-valid
  $ feature_to_server root/app -fake-valid
  $ fe show root/app/child -included-features
  ()
  $ fe show root/app -included-features
  (root/app/child root/app/child/nested)
  $ fe show root/app | stabilize_output root/app
  root/app
  ========
  description of app
  
  |---------------------------------------------------------|
  | attribute               | value                         |
  |-------------------------+-------------------------------|
  | next step               | release                       |
  | owner                   | unix-login-for-testing        |
  | whole-feature reviewers | unix-login-for-testing, user1 |
  | seconder                | user1                         |
  | review is enabled       | true                          |
  | reviewing               | all                           |
  | is permanent            | true                          |
  | tip                     | {REVISION 4}                  |
  | base                    | {REVISION 1}                  |
  | release into me         |                               |
  |   release process       | direct                        |
  |   who can release       | my owners                     |
  |---------------------------------------------------------|
  
  |-----------------------------------------------|
  | user                   | catch-up | completed |
  |------------------------+----------+-----------|
  | user1                  |        2 |         2 |
  | unix-login-for-testing |          |         2 |
  |-----------------------------------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  $ fe show root/app -omit-description -omit-completed-review | stabilize_output root/app
  root/app
  ========
  
  |---------------------------------------------------------|
  | attribute               | value                         |
  |-------------------------+-------------------------------|
  | next step               | release                       |
  | owner                   | unix-login-for-testing        |
  | whole-feature reviewers | unix-login-for-testing, user1 |
  | seconder                | user1                         |
  | review is enabled       | true                          |
  | reviewing               | all                           |
  | is permanent            | true                          |
  | tip                     | {REVISION 4}                  |
  | base                    | {REVISION 1}                  |
  | release into me         |                               |
  |   release process       | direct                        |
  |   who can release       | my owners                     |
  |---------------------------------------------------------|
  
  |------------------|
  | user  | catch-up |
  |-------+----------|
  | user1 |        2 |
  |------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  $ fe show root/app -omit-attribute-table -omit-completed-review
  root/app
  ========
  description of app
  
  |------------------|
  | user  | catch-up |
  |-------+----------|
  | user1 |        2 |
  |------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  $ fe show root/app -show-included-feature-details -omit-attribute-table -omit-completed-review
  root/app
  ========
  description of app
  
  |------------------|
  | user  | catch-up |
  |-------+----------|
  | user1 |        2 |
  |------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  
  root/app/child
  ==============
  description of child
  
  root/app/child/nested
  =====================
  Description of nested child.
  With multiple lines.
  $ fe show root/app -org-mode -show-diff-stat -show-included-feature-details | stabilize_output root/app
  * root/app
  : description of app
  ** Attributes
  |---------------------------------------------------------|
  | attribute               | value                         |
  |-------------------------+-------------------------------|
  | next step               | release                       |
  | owner                   | unix-login-for-testing        |
  | whole-feature reviewers | unix-login-for-testing, user1 |
  | seconder                | user1                         |
  | review is enabled       | true                          |
  | reviewing               | all                           |
  | is permanent            | true                          |
  | tip                     | {REVISION 4}                  |
  | base                    | {REVISION 1}                  |
  | release into me         |                               |
  |   release process       | direct                        |
  |   who can release       | my owners                     |
  |---------------------------------------------------------|
  * Included feature names
  - root/app/child
  - root/app/child/nested
  * Included features
  ** root/app/child
  : description of child
  *** Attributes
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 2}                         |
  |----------------------------------------------------------------|
  *** Affected files
  : file |  2 +-
  : 1 files changed, 1 insertions(+), 1 deletions(-)
  *** root/app/child/nested
  : Description of nested child.
  : With multiple lines.
  **** Attributes
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 3}                         |
  |----------------------------------------------------------------|
  **** Affected files
  : file |  2 +-
  : 1 files changed, 1 insertions(+), 1 deletions(-)
  $ fe show root/app -show-included-feature-details -omit-completed-review | stabilize_output root/app
  root/app
  ========
  description of app
  
  |---------------------------------------------------------|
  | attribute               | value                         |
  |-------------------------+-------------------------------|
  | next step               | release                       |
  | owner                   | unix-login-for-testing        |
  | whole-feature reviewers | unix-login-for-testing, user1 |
  | seconder                | user1                         |
  | review is enabled       | true                          |
  | reviewing               | all                           |
  | is permanent            | true                          |
  | tip                     | {REVISION 4}                  |
  | base                    | {REVISION 1}                  |
  | release into me         |                               |
  |   release process       | direct                        |
  |   who can release       | my owners                     |
  |---------------------------------------------------------|
  
  |------------------|
  | user  | catch-up |
  |-------+----------|
  | user1 |        2 |
  |------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  
  root/app/child
  ==============
  description of child
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 2}                         |
  |----------------------------------------------------------------|
  
  root/app/child/nested
  =====================
  Description of nested child.
  With multiple lines.
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 3}                         |
  |----------------------------------------------------------------|

-org-mode works when not in the repo.

  $ diff <( fe show root/app -org-mode ) <( cd $IRON_TEST_DIR && fe show root/app -org-mode )

-org-mode -show-diff-stat fails well when not in the repo.

  $ ( cd $HOME/workspaces && \
  >     IRON_OPTIONS='((workspaces false))' fe show root/app -org-mode -show-diff-stat
  > )
  -show-diff-stat requires being in a clone of $TESTCASE_ROOT/repo.
  [1]

Checking persistency

  $ fe-server stop
  $ fe-server start
  $ fe show root/app/child -included-features
  ()
  $ fe show root/app -included-features
  (root/app/child root/app/child/nested)

Release a feature with included features into a root

  $ make_releasable root/app
  $ fe internal render-release-email root/app | stabilize_output root/app
  root/app
  ========
  description of app
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | review is enabled       | true                                 |
  | reviewing               | all                                  |
  | is permanent            | true                                 |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 1}                         |
  | release into me         |                                      |
  |   release process       | direct                               |
  |   who can release       | my owners                            |
  |----------------------------------------------------------------|
  
  Included features:
    root/app/child
    root/app/child/nested
  
  root/app/child
  ==============
  description of child
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 2}                         |
  |----------------------------------------------------------------|
  
  root/app/child/nested
  =====================
  Description of nested child.
  With multiple lines.
  
  |----------------------------------------------------------------|
  | attribute               | value                                |
  |-------------------------+--------------------------------------|
  | id                      | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
  | owner                   | unix-login-for-testing               |
  | whole-feature reviewers | unix-login-for-testing, user1        |
  | seconder                | user1                                |
  | tip                     | {REVISION 4}                         |
  | base                    | {REVISION 3}                         |
  |----------------------------------------------------------------|
  $ fe release root/app
  $ feature_to_server root/app -fake-valid
  $ feature_to_server root -fake-valid
  $ fe show root/app -included-features
  ()
  $ fe show root -included-features
  (root/app root/app/child root/app/child/nested)

Look at the diff of a released feature.  Make sure it is not the empty diff.

  $ fe diff root/app/child/nested -archived | fe internal remove-color | stabilize_output root
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ file @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  scrutiny level10
  base {REVISION 3} | tip {REVISION 4}
  @@@@@@@@ base 1,2 tip 1,2 @@@@@@@@
  -|3
  +|4

Check that [fe show] displays the base and tip as of before the latest release.

  $ diff \
  >   <(fe show root/app/child/nested -archived -base) \
  >   <(fe show root/app/child/nested -archived -tip)  \
  > >/dev/null
  [1]

  $ [ ${nested_child_base} = $(fe show root/app/child/nested -archived -base) ]
  $ [ ${nested_child_tip}  = $(fe show root/app/child/nested -archived -tip)  ]

  $ old_tip=$(fe show -tip root)

  $ hg update root >/dev/null
  $ fe create root/aap2 -d "another app"
  $ echo 5 > file; hg commit -m 5
  $ fe enable
  $ feature_to_server root/aap2 -fake-valid
  $ fe change -add-whole-feature-reviewers user1
  $ IRON_USER=user1 fe second
  $ make_releasable root/aap2
  $ fe release root/aap2

  $ fe show root -included-features -order-included-features-by-release-time | sexp query each
  root/app
  root/app/child
  root/app/child/nested
  root/aap2

  $ fe show root -included-feature -order-included-features-by-decreasing-release-time | sexp query each
  root/aap2
  root/app/child/nested
  root/app/child
  root/app

  $ fe show root -included-features | sexp query each
  root/aap2
  root/app
  root/app/child
  root/app/child/nested

  $ fe show root -included-features \
  >  -order-included-features-by-release-time \
  >  -order-included-features-by-decreasing-release-time
  ("These flags are mutually exclusive."
   -order-included-features-by-decreasing-release-time
   -order-included-features-by-release-time)
  [1]

Check that tips of included features are ancestors of feature tip.

  $ feature_to_server root -fake-valid
  $ new_tip=$(fe show -tip root)
  $ fe internal invariant included-features root/aap2
  ("no such feature" root/aap2)
  [1]
  $ fe internal invariant included-features root
  $ hg bookmark -f -r ${old_tip} root
  $ feature_to_server root -fake-valid
  $ fe internal invariant included-features root |& stabilize_output root
  (root "has tip" {REVISION 4}
   "which does not descend from these included features:" (root/aap2))
  [1]
  $ hg bookmark -f -r ${new_tip} root
  $ feature_to_server root -fake-valid

