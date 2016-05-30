open Core.Std
open Async.Std
open Import



let name_filter_diffs ~which_files (diff4s : Diff4.t list) =
  match which_files with
  | `All -> diff4s  (* No -file arguments means select everything *)
  | `Files files ->
    let unused = Path_in_repo.Hash_set.of_list files in
    let files  = Path_in_repo.Set.of_list files in
    let keep =
      List.filter diff4s ~f:(fun diff4 ->
        let path = Diff4.path_in_repo_at_f2 diff4 in
        Set.mem files path
        && (Hash_set.remove unused path; true))
    in
    let unused = Hash_set.to_list unused in
    if not (List.is_empty unused)
    then failwiths "-file selections not found" unused
           [%sexp_of: Path_in_repo.t list];
    keep
;;

let command =
  Command.async'
    ~summary:"show the diff of a feature"
    ~readme: (fun () -> "\
One can use any number of [-file FILE] switches to choose which files to show.
If no [-file] switches are provided, the diff for all files is shown.
")
    (let open Command.Let_syntax in
     let%map_open () = return ()
     and what_feature = maybe_archived_feature
     and even_ignored =
       no_arg_flag "-even-ignored"
         ~doc:"consider all files, even those not seen by whole-feature reviewers"
     and for_ = for_or_all_default_all
     and which_files =
       which_files
     and context = context ()
     and max_output_columns = max_output_columns
     and may_modify_local_repo = may_modify_local_repo
     and raw =
       no_arg_flag "-raw" ~doc:"show Iron's internal representation of the diff"
     and sort_build_order = sort_build_order
     and summary = no_arg_flag "-summary" ~doc:"show a summary of the diff"
     in
     fun () ->
       let open! Deferred.Let_syntax in
       let display_ascii = Iron_options.display_ascii_always in
       let what_diff : What_diff.t =
         match even_ignored, for_ with
         | false, `All_users -> Whole_diff
         | false, `User u    -> For u
         | true , `All_users -> Whole_diff_plus_ignored
         | true , `User _    -> failwith "cannot use -even-ignored and -for USER"
       in
       let%bind what_feature =
         Command.Param.resolve_maybe_archived_feature_spec_exn (ok_exn what_feature)
       in
       let%bind ({ feature_path
                 ; is_archived
                 ; diff_from_base_to_tip
                 ; tip
                 ; remote_repo_path
                 ; _
                 } as feature) =
         Get_feature.Maybe_archived.rpc_to_server_exn { what_feature; what_diff }
       in
       let%bind repo_root =
         (* When looking at a diff, you often don't need to do any further operations in
            the repo, so just use the root clone instead of a share. *)
         Cmd_workspace.repo_for_hg_operations_exn feature_path
           ~use:(if is_archived then `Clone else `Share_or_clone_if_share_does_not_exist)
       in
       let reviewer =
         match what_diff with
         | Whole_diff_plus_ignored -> `Whole_diff_plus_ignored
         | Whole_diff | None -> `Reviewer Reviewer.synthetic_whole_feature_reviewer
         | For user_name -> `Reviewer (Feature.reviewer_in_feature feature user_name)
       in
       let diff4s =
         match diff_from_base_to_tip with
         | Pending_since _ | Known (Error _ ) as x -> x
         | Known (Ok diffs) ->
           let diff4s =
             name_filter_diffs ~which_files
               (diffs |> List.map ~f:Diff4.create_from_scratch_to_diff2)
           in
           Known (Ok diff4s)
       in
       if raw then begin
         print_endline (diff4s
                        |> [%sexp_of: Diff4.t list Or_error.t Or_pending.t]
                        |> Sexp.to_string_hum);
         return ();
       end else begin
         match diff4s with
         | Pending_since since ->
           if is_archived
           then failwith "[fe diff -archived] is not available for this archived feature"
           else
             die "diffs have been pending for"
               (Time.Span.to_short_string (how_long ~since))
               [%sexp_of: string]
         | Known (Error error) ->
           die "diffs cannot be computed" error [%sexp_of: Error.t];
         | Known (Ok diff4s) ->
           let%bind diff4s =
             begin
               if sort_build_order
               then Build_order.sort repo_root diff4s Diff4.path_in_repo_at_f2
               else return
                      (List.sort diff4s ~cmp:(fun d1 d2 ->
                         Path_in_repo.default_review_compare
                           (Diff4.path_in_repo_at_f2 d1)
                           (Diff4.path_in_repo_at_f2 d2)))
             end
           in
           if summary
           then begin
             print_string
               (Ascii_table.to_string
                  (Diff4.summary diff4s ~sort:false) (* already sorted above *)
                  ~display_ascii
                  ~max_output_columns);
             return ();
           end else begin
             let%bind () =
               (if not may_modify_local_repo
                then return ()
                else
                  Hg.pull repo_root ~from:remote_repo_path
                    ~even_if_unclean:true (`Rev tip))
             in
             Cmd_review.print_diff4s
               ~repo_root
               ~diff4s
               ~reviewer
               ~context
           end
       end
    )
;;
