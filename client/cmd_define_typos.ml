open! Core
open! Async
open! Import

let command =
  Command.async'
    ~summary:"define the user for a mistyped user name"
    ~readme:(fun () ->
      "These are used to reassign crs that have typos in usernames.\n\n\
       The intended usage for defining multiple typos at once is:\n\n\
      \   fe admin users define-typos \\\n\
      \       -typo TYPO1 -means USER1 \\\n\
      \       -typo TYPO2 -means USER2 \\\n\
      \       -typo TYPO3 -means USER3 \\\n\
      \       ;\n")
    (let open Command.Let_syntax in
    let%map_open () = return ()
    and typos = flag "-typo" (listed typo) ~doc:"TYPO "
    and means =
      flag
        "-means"
        (listed user_name)
        ~doc:"USER the nth user is matched with the nth typo"
    and may_repartition_crs = may_repartition_crs in
    fun () ->
      let definitions =
        List.map2_exn typos means ~f:(fun typo means ->
          { Define_typos.Definition.typo; means })
      in
      Define_typos.rpc_to_server_exn { definitions; may_repartition_crs })
;;
