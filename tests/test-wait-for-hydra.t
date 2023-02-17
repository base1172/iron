  $ source ./bin/setup-script
  $ start_test

A feature starts pending

  $ setup_repo_and_root file
  $ fe tools wait-for-hydra -timeout 1s -do-not-modify-local-repo 2>&1 |& sanitize_output
  ("timed out after waiting 1s for hydra to process root"
   ((waiting_since ({ELIDED}                           ))
    (reason_for_waiting
     (Expecting_bookmark_update
      (Update_expected_since ({ELIDED}                           ))))))
  [1]

Until we get an update bookmark

  $ feature_to_server root
  $ fe tools wait-for-hydra -timeout 1s -do-not-modify-local-repo

If the tip of fe and remote tip (ie local tip here) don't agree, we
also have to wait too:

  $ echo 'hello' >file; hg com -m change
  $ fe tools wait-for-hydra -timeout 1s -do-not-modify-local-repo |& sanitize_output
  ("timed out after waiting 1s for hydra to process root"
   ((waiting_since ({ELIDED}                           ))
    (reason_for_waiting
     (Different_tips ((in_fe {ELIDED}    ) (in_hg {ELIDED}    ))))))
  [1]

Until the next bookmark update.

  $ feature_to_server root
  $ fe tools wait-for-hydra -timeout 1s -do-not-modify-local-repo
