Start test.

  $ source ./bin/setup-script
  $ start_test

Create a simple feature hierarchy.

  $ setup_repo_and_root file
  $ fe create root/parent
  $ fe create root/other-parent

Start the pipe in the background, redirecting its output.

  $ dump_file=../updates.sexp
  $ ( fe internal notify-on-descendant-updates root/parent ; \
  >   echo "Process Exited" ) >> ${dump_file} &
  $ dump_process_pid=$!
  $ trap 'kill ${dump_process_pid} &> /dev/null || true; exit_trap' EXIT

Create a child of the feature we are listening to.

  $ fe create root/parent/child
  $ cat_then_truncate
  Updates_in_subtree

Show the current event subscriptions.

  $ fe internal event-subscriptions show \
  >   | sexp change '(bottomup (seq (try (rewrite (query @X) (query <query>))) (try (rewrite (opened_at @X) (opened_at <time>)))))'
  (((metric_updates
     ((metric_name_subscriptions ()) (feature_path_subscriptions ())))
    (feature_updates
     ((feature_only_subscriptions ())
      (feature_and_descendants_subscriptions
       ((root/parent (1 unix-login-for-testing)))))))
   ((max_subscriptions_global 500) (current_count_global 1)
    (max_subscriptions_per_user 50)
    (current_count_by_user ((unix-login-for-testing 1)))
    (subscriptions
     (((rpc_name notify-on-descendant-updates) (rpc_version 2)
       (opened_at <time>) (ticks 1) (query <query>))))))

Rename the feature so that it leaves the subtree we are listening to.

  $ fe rename root/parent/child root/other-parent/child
  $ cat_then_truncate
  Updates_in_subtree

Rename the feature so that it re-enters the subtree.

  $ fe rename root/other-parent/child root/parent/child
  $ cat_then_truncate
  Updates_in_subtree

Archive the feature so that is leaves the subtree.

  $ ARCHIVED_ID=$(fe show root/parent/child -id)
  $ fe archive root/parent/child
  $ cat_then_truncate
  Updates_in_subtree

Create a new subfeature in the subtree

  $ fe create root/parent/other-child -description 'other-child'
  $ cat_then_truncate
  Updates_in_subtree

Unarchive a feature so that it re-enters the subtree.

  $ fe unarchive root/parent/child -id ${ARCHIVED_ID}
  $ cat_then_truncate
  Updates_in_subtree

Rename the parent feature and verify that the pipe closes.  We wait on
[root/parent] to address the following race condition: by the time [fe rename]
returns, the initial subscriber may not have seen the last renamed event.

  $ fe rename root/parent root/renamed-parent
  $ wait ${dump_process_pid}
  $ cat_then_truncate
  Renamed
  Process Exited

Clean up the dump file.

  $ rm -f ${dump_file}

And finally check that the event-subscriptions structure get cleaned up:

  $ fe internal event-subscriptions show
  (((metric_updates
     ((metric_name_subscriptions ()) (feature_path_subscriptions ())))
    (feature_updates
     ((feature_only_subscriptions ())
      (feature_and_descendants_subscriptions ()))))
   ((max_subscriptions_global 500) (current_count_global 0)
    (max_subscriptions_per_user 50) (current_count_by_user ())
    (subscriptions ())))
