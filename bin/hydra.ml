open Core
open Async

let cmd_top =
  let open Command.Let_syntax in
  Command.async_or_error
    ~summary:"hydra worker"
    [%map_open
      let args = anon (sequence ("ARG" %: string)) in
      fun () ->
        Deferred.Or_error.error_s
          [%message "hydra invoked with args" (args : string list)]]
;;

let () = Command_unix.run cmd_top
