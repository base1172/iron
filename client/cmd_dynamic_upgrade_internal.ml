open! Core
open! Async
open! Import

let set =
  Command.async'
    ~summary:"set the dynamic upgrade state"
    (let open Command.Let_syntax in
    let%map_open () = return ()
    and set_to = enum_anon "UPGRADE" (module Dynamic_upgrade) in
    fun () ->
      let open! Deferred.Let_syntax in
      With_dynamic_upgrade_state.rpc_to_server_exn (Set set_to))
;;

let show =
  Command.async'
    ~summary:"show the dynamic upgrade state"
    (let open Command.Let_syntax in
    let%map_open () = return () in
    fun () ->
      let open! Deferred.Let_syntax in
      Cmd_dump.dump Dynamic_upgrade_state)
;;

let command =
  Command.group
    ~summary:"dynamic upgrade of the server"
    ~readme:(fun () ->
      concat
        [ "When a roll introduces new persisted types, typically there is a period of \
           time directly\n\
           following the roll during which we prevent values from being persisted if \
           they cannot be\n\
           deserialized by the previous binary.  The reason is that we want to be able \
           to roll back:\n\
           the previous binary needs to be able to reload the persisted state.  Those \
           non backward\n\
           compatible changes are identified and grouped by [upgrades].\n\n\
           An admin can dynamically enable a new upgrade, by calling the relevant RPC.  \
           By doing so\n\
           they commit to the changes and give up the ability to roll back.\n"
        ])
    [ "set", set; "show", show ]
;;
