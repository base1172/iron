open Core
open Async
open! Import
open Iron_hg
open Iron_obligations.Std
open Iron_protocol

let use_or_compute_and_store worker_cache_session key rev compute =
  Worker_cache.Worker_session.use_or_compute_and_store
    worker_cache_session
    key
    rev
    compute
;;

let compute_obligations_uncached repo_root ~repo_is_clean ~aliases rev =
  let%bind () = Hg.update repo_root (`Rev rev) ~clean_after_update:No in
  let%map obligations_are_valid, obligations, obligations_version =
    Rev_facts.Obligations_are_valid.create_exn repo_root ~repo_is_clean rev ~aliases
  in
  { Worker_obligations.obligations_are_valid; obligations; obligations_version }
;;

let compute_obligations repo_root ~repo_is_clean rev ~aliases ~worker_cache_session =
  let compute = compute_obligations_uncached repo_root ~repo_is_clean ~aliases in
  use_or_compute_and_store worker_cache_session Worker_obligations rev compute
;;

let compute_worker_rev_facts_uncached
  repo_root
  ~repo_is_clean
  ~aliases
  ?try_incremental_computation_based_on
  ~worker_cache_session
  rev
  =
  let cached_facts_for_incremental_computation =
    let open Option.Let_syntax in
    let%bind base_rev = try_incremental_computation_based_on in
    let%bind { Worker_rev_facts.rev_facts = _; crs; cr_soons } =
      Worker_cache.Worker_session.find worker_cache_session base_rev Worker_rev_facts
    in
    match crs, cr_soons with
    | Error _, _ | _, Error _ -> None
    | Ok due_now, Ok due_soon ->
      let%bind { Worker_obligations.obligations_version; _ } =
        Worker_cache.Worker_session.find worker_cache_session base_rev Worker_obligations
      in
      let%map base_cr_format =
        match obligations_version with
        | Error _ -> None
        | Ok obligations_version ->
          Some (Obligations_version.cr_comment_format obligations_version)
      in
      { Cr_comment.Cached_facts_for_incremental_computation.base_rev
      ; base_crs = { due_now; due_soon }
      ; base_cr_format
      }
  in
  let%bind () = Hg.update repo_root (`Rev rev) ~clean_after_update:No in
  let%bind conflict_free =
    Rev_facts.Is_conflict_free.create repo_root ~repo_is_clean rev
  in
  let%bind { Worker_obligations.obligations_are_valid; obligations; obligations_version } =
    compute_obligations repo_root ~repo_is_clean rev ~aliases ~worker_cache_session
  in
  let file_owner =
    match obligations with
    | Error _ -> const (error_string "broken obligations")
    | Ok obligations -> Obligations.file_owner obligations
  in
  let%map is_cr_clean, crs_or_error =
    Rev_facts.Is_cr_clean.create
      repo_root
      ~repo_is_clean
      (Or_error.map obligations_version ~f:Obligations_version.cr_comment_format)
      ~incremental_based_on:cached_facts_for_incremental_computation
      rev
      ~file_owner
  in
  let crs, cr_soons =
    match crs_or_error with
    | Error _ as e -> e, e
    | Ok { due_now; due_soon } -> Ok due_now, Ok due_soon
  in
  let rev_facts =
    ok_exn (Rev_facts.create conflict_free is_cr_clean obligations_are_valid)
  in
  { Worker_rev_facts.rev_facts; crs; cr_soons }
;;

let compute_worker_rev_facts
  repo_root
  ~repo_is_clean
  ~rev
  ~aliases
  ?try_incremental_computation_based_on
  ~worker_cache_session
  ()
  =
  let compute =
    compute_worker_rev_facts_uncached
      repo_root
      ~repo_is_clean
      ~aliases
      ?try_incremental_computation_based_on
      ~worker_cache_session
  in
  let%bind { Worker_rev_facts.rev_facts; crs; cr_soons } =
    use_or_compute_and_store worker_cache_session Worker_rev_facts rev compute
  in
  let result =
    (* Always use the latest available inferred human name *)
    { Worker_rev_facts.rev_facts = Rev_facts.with_rev_exn rev_facts rev; crs; cr_soons }
  in
  (* In case we used a cached [Worker_rev_facts.t] value, we may not have computed the
     obligations.  We'll need it later anyway and now is a better time than another
     because we are already at the right revision. *)
  let%map { Worker_obligations.obligations; _ } =
    compute_obligations repo_root ~repo_is_clean rev ~aliases ~worker_cache_session
  in
  result, obligations
;;

let all_obligations
  ~base_is_ancestor_of_tip
  ~obligations_at_tip
  ~tip
  ~obligations_at_base
  ~base
  ~aliases
  ~worker_cache_session
  repo_root
  ~repo_is_clean
  need_diff4s_starting_from
  =
  let base_is_ancestor_of_tip =
    Rev_facts.Is_ancestor.check base_is_ancestor_of_tip ~ancestor:base ~descendant:tip
    |> ok_exn
  in
  match obligations_at_tip, obligations_at_base, base_is_ancestor_of_tip with
  | (Error _ as e), _, _ | _, (Error _ as e), _ -> return e
  | _, _, false ->
    return
      (error_string "avoiding a costly computation, since tip doesn't descend from base")
  | Ok obligations_at_tip, Ok obligations_at_base, true ->
    let obligations_by_rev = Rev.Compare_by_hash.Map.singleton tip obligations_at_tip in
    let obligations_by_rev =
      Map.set obligations_by_rev ~key:base ~data:obligations_at_base
    in
    let all_revs =
      List.concat_map need_diff4s_starting_from ~f:(fun { Review_edge.base; tip } ->
        [ base; tip ])
    in
    let rec loop obligations_by_rev = function
      | [] -> return (Ok obligations_by_rev)
      | rev :: revs ->
        if Map.mem obligations_by_rev rev
        then loop obligations_by_rev revs
        else (
          let%bind { Worker_obligations.obligations; _ } =
            compute_obligations
              repo_root
              ~repo_is_clean
              rev
              ~aliases
              ~worker_cache_session
          in
          match obligations with
          | Error _ as e -> return e
          | Ok obligations ->
            let obligations_by_rev =
              Map.set obligations_by_rev ~key:rev ~data:obligations
            in
            loop obligations_by_rev revs)
    in
    loop obligations_by_rev all_revs
;;

module Worker = struct
  let maybe_update_bookmark
    ~repo_root
    ~feature_path
    ~base
    ~aliases
    ~tip
    ~need_diff4s_starting_from
    ~lines_required_to_separate_ddiff_hunks
    ~worker_cache_session
    =
    let review_edge_from_base_to_base = { Review_edge.base; tip = base } in
    let need_diff4s_starting_from =
      List.dedup_and_sort
        ~compare:Review_edge.compare
        (review_edge_from_base_to_base :: need_diff4s_starting_from)
    in
    let base_is_ancestor_of_tip_def =
      Rev_facts.Is_ancestor.create repo_root ~ancestor:base ~descendant:tip
    in
    let%bind repo_is_clean = Hg.status_cleanliness repo_root in
    let repo_is_clean = ok_exn repo_is_clean in
    let%bind () =
      printf "Check equality of tip facts computed from scratch and incrementally...\n";
      let%bind (_ : Worker_rev_facts.t * Obligations.t Or_error.t) =
        compute_worker_rev_facts
          repo_root
          ~repo_is_clean
          ~rev:base
          ~aliases
          ~worker_cache_session
          ()
      in
      Worker_cache.Worker_session.remove worker_cache_session tip Worker_rev_facts;
      let%bind tip_facts_from_scratch, (_ : Obligations.t Or_error.t) =
        compute_worker_rev_facts
          repo_root
          ~repo_is_clean
          ~rev:tip
          ~aliases
          ?try_incremental_computation_based_on:None
          ~worker_cache_session
          ()
      in
      Worker_cache.Worker_session.remove worker_cache_session tip Worker_rev_facts;
      let%bind tip_facts_incremental, (_ : Obligations.t Or_error.t) =
        compute_worker_rev_facts
          repo_root
          ~repo_is_clean
          ~rev:tip
          ~aliases
          ~try_incremental_computation_based_on:base
          ~worker_cache_session
          ()
      in
      let tip_facts_from_scratch =
        Worker_rev_facts.for_sorted_output tip_facts_from_scratch
      in
      let tip_facts_incremental =
        Worker_rev_facts.for_sorted_output tip_facts_incremental
      in
      [%test_result: Worker_rev_facts.t]
        ~message:"inconsistent tip worker_rev_facts results"
        ~expect:tip_facts_from_scratch
        tip_facts_incremental;
      return ()
    in
    let%bind ( { Worker_rev_facts.rev_facts = tip_facts
               ; crs = crs_at_tip
               ; cr_soons = cr_soons_at_tip
               }
             , obligations_at_tip )
      =
      compute_worker_rev_facts
        repo_root
        ~repo_is_clean
        ~rev:tip
        ~aliases
        ~try_incremental_computation_based_on:base
        ~worker_cache_session
        ()
    in
    (* BEWARE: At this point, the working copy may or may not have the initial revision *)
    let base_facts_def =
      if Rev.Compare_by_hash.( = ) base tip
      then
        return
          ( { Worker_rev_facts.rev_facts = Rev_facts.with_rev_exn tip_facts base
            ; crs = crs_at_tip
            ; cr_soons = cr_soons_at_tip
            }
          , obligations_at_tip )
      else
        compute_worker_rev_facts
          repo_root
          ~repo_is_clean
          ~rev:base
          ~aliases
          ~worker_cache_session
          ()
    in
    let%bind ( ( { Worker_rev_facts.rev_facts = base_facts
                 ; crs = _
                 ; cr_soons = cr_soons_at_base
                 }
               , obligations_at_base )
             , base_is_ancestor_of_tip )
      =
      Deferred.both base_facts_def base_is_ancestor_of_tip_def
    in
    let%bind obligations_by_rev =
      all_obligations
        repo_root
        ~repo_is_clean
        need_diff4s_starting_from
        ~base_is_ancestor_of_tip
        ~tip
        ~obligations_at_tip
        ~base
        ~obligations_at_base
        ~aliases
        ~worker_cache_session
    in
    let%bind diffs_by_review_edge =
      match obligations_by_rev with
      | Error _ as e -> return e
      | Ok obligations_by_rev ->
        let b2 = base
        and f2 = tip in
        let diamonds =
          List.map need_diff4s_starting_from ~f:(fun { base = b1; tip = f1 } ->
            { Diamond.b1; b2; f1; f2 })
        in
        Diff4s_for_diamond.Cache.with_
          ~time:(fun (_ : string) -> ())
          repo_root
          obligations_by_rev
          diamonds
          ~f:(fun cache ->
            Deferred.List.map diamonds ~f:(fun diamond ->
              let%map diffs =
                Diff4s_for_diamond.create
                  cache
                  diamond
                  ~lines_required_to_separate_ddiff_hunks
              in
              let { Diamond.b1; f1; _ } = diamond in
              { Review_edge.base = b1; tip = f1 }, diffs))
        >>| Or_error.return
    in
    let cr_soons =
      match cr_soons_at_base, cr_soons_at_tip with
      | Error _, _ | _, Error _ ->
        error_s
          [%sexp
            "cannot find CR-soons"
            , { base = (cr_soons_at_base : _ Or_error.t)
              ; tip = (cr_soons_at_tip : _ Or_error.t)
              }]
      | Ok base_cr_soons, Ok tip_cr_soons ->
        Cr_soons.In_feature.create
          ~feature_path
          ~base_facts
          ~base_cr_soons
          ~tip_facts
          ~tip_cr_soons
          ~base_is_ancestor_of_tip
    in
    let diff4s =
      Or_error.map diffs_by_review_edge ~f:(fun diffs_by_review_edge ->
        List.concat_map diffs_by_review_edge ~f:snd)
    in
    let diff_from_base_to_tip =
      match diffs_by_review_edge with
      | Error _ as e -> e
      | Ok l ->
        let diffs =
          List.Assoc.find_exn l review_edge_from_base_to_base ~equal:(fun x y ->
            [%compare: Review_edge.t] x y = 0)
        in
        Ok
          (List.map diffs ~f:(fun diff4 ->
             match Diff4.as_from_scratch_to_diff2 diff4 with
             | Some diff2 -> diff2
             | None -> raise_s [%sexp "diff4 should have been a diff2", (diff4 : Diff4.t)]))
    in
    let base_allow_review_for =
      Result.map
        obligations_at_base
        ~f:(fun { Iron_obligations.Obligations.obligations_repo; _ } ->
        match obligations_repo with
        | `Fake ->
          (* This case happens when we fake valid obligations in functional tests, and in
                   that case we want to allow all [fe review -for]. *)
          Allow_review_for.all
        | `Actual { Iron_obligations.Obligations_repo.allow_review_for; _ } ->
          allow_review_for)
    in
    (* We want to make sure that invalid [base_allow_review_for] are reported by Iron, so
       we check that invalid [base_allow_review_for] implies invalid [base_facts]. *)
    if is_error base_allow_review_for
    then
      assert (
        not
          (ok_exn
             (Rev_facts.Obligations_are_valid.check
                base_facts.obligations_are_valid
                (Rev_facts.rev base_facts))));
    Deferred.Or_error.return
      { Update_bookmark.Info.crs_at_tip
      ; base_is_ancestor_of_tip
      ; base_facts
      ; tip_facts
      ; base_allow_review_for
      ; diff_from_base_to_tip
      ; diff4s
      ; cr_soons
      }
  ;;

  module Cmd = struct
    let update_bookmark () =
      let open Command.Let_syntax in
      Async.Command.async_or_error
        ~summary:"start a hydra worker to update the bookmark for a feature"
        [%map_open
          let bookmark = anon (maybe ("BOOKMARK feature name or bookmark" %: string)) in
          fun () ->
            let open Deferred.Or_error.Let_syntax in
            let%bind repo_root = Deferred.return Repo_root.program_started_in in
            let%bind bookmark =
              match bookmark with
              | Some bookmark -> Deferred.Or_error.return bookmark
              | None -> Hg.current_bookmark repo_root
            in
            let%bind rev_zero =
              Hg.create_rev_zero repo_root |> Deferred.map ~f:Result.return
            in
            let%bind tip = Hg.create_rev repo_root Hg.Revset.dot in
            Log.Global.info !"tip = %s, bookmark = %s\n" (Rev.to_string_40 tip) bookmark;
            let%bind feature_path =
              Deferred.return (Feature_path.of_string_or_error bookmark)
            in
            let%bind { base
                     ; feature_id
                     ; need_diff4s_starting_from
                     ; aliases
                     ; lines_required_to_separate_ddiff_hunks
                     ; worker_cache
                     }
              =
              Hydra_worker.rpc_to_server { feature_path; rev_zero; tip = Some tip }
            in
            let worker_cache_session = Worker_cache.Worker_session.create worker_cache in
            let%bind info =
              let need_diff4s_starting_from = List.map need_diff4s_starting_from ~f:fst in
              maybe_update_bookmark
                ~repo_root
                ~feature_path
                ~base
                ~aliases
                ~tip
                ~need_diff4s_starting_from
                ~lines_required_to_separate_ddiff_hunks
                ~worker_cache_session
            in
            Update_bookmark.rpc_to_server
              { feature_path
              ; feature_id
              ; info = Ok info
              ; augment_worker_cache =
                  Worker_cache.Worker_session.back_to_server worker_cache_session
              }]
    ;;

    let group () =
      Command.group ~summary:"hydra worker" [ "update-bookmark", update_bookmark () ]
    ;;
  end
end

let cmd () = Command.group ~summary:"hydra" [ "worker", Worker.Cmd.group () ]
let () = Command_unix.run (cmd ())
