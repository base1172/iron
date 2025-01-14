open! Core
open! Async
open! Import
module Command = Core.Command

module Mode = struct
  module T = struct
    type t =
      [ `Prod
      | `Dev
      ]
    [@@deriving compare]

    let to_string : t -> string = function
      | `Prod -> "prod"
      | `Dev -> "dev"
    ;;

    let of_string : string -> t = function
      | "Prod" | "prod" -> `Prod
      | "Dev" | "dev" -> `Dev
      | str -> failwithf "Illegal string %s. Expected 'prod' or 'dev'." str ()
    ;;
  end

  include T
  include Sexpable.Of_stringable (T)

  include Comparable.Make (struct
    include T
    include Sexpable.Of_stringable (T)
  end)
end

module Instance_arg = struct
  type 'a t =
    | Optional : string option t
    | Required : string t
end

let common_flags
  (type instance_arg)
  ~(instance_arg : instance_arg Instance_arg.t)
  ~appdir_for_doc
  ~appdir
  =
  let open Command.Spec in
  match instance_arg with
  | Optional ->
    step (fun k ~appdir ~(instance : instance_arg) ~mode ->
      let basedir = appdir ^/ Mode.to_string mode in
      k ~basedir ~instance ~mode)
    ++ step (fun k x -> k ~appdir:x)
    +> flag
         "-appdir"
         (optional_with_default appdir Filename_unix.arg_type)
         ~doc:("DIR override default APPDIR of " ^ appdir_for_doc)
    ++ step (fun k (x : instance_arg) -> k ~instance:x)
    +> flag "-instance" (optional string) ~doc:"INSTANCE instance name"
    ++ step (fun k x -> k ~mode:x)
    +> flag
         "-mode"
         (optional_with_default `Prod (Arg_type.create Mode.of_string))
         ~doc:"MODE running mode, prod/dev (default = prod)"
  | Required ->
    step (fun k ~appdir ~(instance : instance_arg) ~mode ->
      let basedir = appdir ^/ Mode.to_string mode in
      k ~basedir ~instance ~mode)
    ++ step (fun k x -> k ~appdir:x)
    +> flag
         "-appdir"
         (optional_with_default appdir Filename_unix.arg_type)
         ~doc:("DIR override default APPDIR of " ^ appdir_for_doc)
    ++ step (fun k (x : instance_arg) -> k ~instance:x)
    +> flag "-instance" (required string) ~doc:"INSTANCE instance name"
    ++ step (fun k x -> k ~mode:x)
    +> flag
         "-mode"
         (optional_with_default `Prod (Arg_type.create Mode.of_string))
         ~doc:"MODE running mode, prod/dev (default = prod)"
;;

module Lock_file = struct
  let path (type a) ~(instance_arg : a Instance_arg.t) ~appname ~(instance : a) ~lockdir =
    match instance_arg with
    | Required -> lockdir ^/ sprintf "%s.%s.lock" instance appname
    | Optional ->
      (match instance with
       | None -> lockdir ^/ sprintf "%s.lock" appname
       | Some instance -> lockdir ^/ sprintf "%s.%s.lock" instance appname)
  ;;

  let create_exn ~instance_arg ~appname ~instance ~lockdir =
    let timeout = Core.Time.Span.of_sec 1. in
    let lock_file = path ~instance_arg ~appname ~instance ~lockdir in
    Lock_file_blocking.Nfs.blocking_create ~timeout lock_file
  ;;

  let read_exn ~instance_arg ~appname ~instance ~basedir:lockdir =
    let lock_file = path ~instance_arg ~appname ~instance ~lockdir in
    let is_locked =
      try
        Lock_file_blocking.Nfs.critical_section
          ~timeout:Core.Time.Span.zero
          lock_file
          ~f:(fun () -> false)
      with
      | _ -> true
    in
    if not is_locked
    then failwithf "Lock file %s is not locked by any process" lock_file ()
    else (
      match Lock_file_blocking.Nfs.get_hostname_and_pid lock_file with
      | None -> failwithf "unable to read hostname and pid from %s" lock_file ()
      | Some (host, pid) ->
        let my_host = Unix.gethostname () in
        if String.( <> ) host my_host
        then
          failwithf
            "Hostname in lockfile %s doesn't match current hostname %s"
            host
            my_host
            ()
        else host, pid)
  ;;
end

let configure_log ~log_format ~logdir ~fg =
  let log_rotation = Log.Rotation.default () in
  Log.Global.set_level `Info;
  let output =
    Log.Output.rotating_file log_format log_rotation ~basename:(logdir ^/ "messages")
  in
  let outputs = [ output ] in
  Log.Global.set_output (if fg then Log.Output.stderr () :: outputs else outputs)
;;

let start
  (type a)
  ~(instance_arg : a Instance_arg.t)
  ~init_stds
  ~log_format
  ~appname
  ~main
  ~basedir
  ~(instance : a)
  ~mode
  ~fg
  ()
  =
  let keep_stdout_and_stderr = not fg in
  let logdir = basedir in
  let release_io =
    if fg
    then fun () -> ()
    else (
      let redir filename =
        if keep_stdout_and_stderr then Some (`File_append (logdir ^/ filename)) else None
      in
      Daemon.daemonize_wait
        ?redirect_stdout:(redir "stdout")
        ?redirect_stderr:(redir "stderr")
        ~cd:basedir
        ()
      |> unstage)
  in
  Lock_file.create_exn ~instance_arg ~appname ~instance ~lockdir:basedir;
  configure_log ~log_format ~logdir ~fg;
  Signal.handle [ Signal.term; Signal.int ] ~f:(fun signal ->
    if keep_stdout_and_stderr
    then
      Core.Printf.printf
        !"shutting down upon receiving signal %{Signal} at %{Time}\n%!"
        signal
        (Time.now ());
    Log.Global.info !"shutting down upon receiving signal %{Signal}" signal;
    upon (Log.Global.flushed ()) (fun () -> shutdown 0));
  let tags =
    [ "pid", Pid.to_string (Unix.getpid ())
    ; "version", Version_util.version
    ; "build info", Version_util.build_info
    ; "command line", String.concat ~sep:" " (Array.to_list (Sys.get_argv ()))
    ]
  in
  upon Deferred.unit (fun () ->
    release_io ();
    if keep_stdout_and_stderr && init_stds
    then (
      (* Multiple runs usually append to the same "keep" files, so these separator
         lines are helpful for distinguishing the output of one run from another. *)
      let now = Core.Time.now () in
      List.iter [ Stdio.stdout; Stdio.stderr ] ~f:(fun oc ->
        Core.Printf.fprintf
          oc
          !"%s Daemonized with tags=%{Sexp}\n%!"
          (Core.Time.to_string_abs now ~zone:(force Time_unix.Zone.local))
          ([%sexp_of: (string * string) list] tags))));
  let main =
    Monitor.try_with ~extract_exn:true (fun () ->
      Log.Global.info ~tags !"Starting up";
      (match mode with
       | `Prod -> ()
       | `Dev ->
         Log.Global.set_level `Debug;
         Log.Global.debug "logging at level `Debug because we're in dev mode");
      main ~basedir ~instance ~mode)
  in
  upon main (function
    | Ok () -> shutdown 0
    | Error e ->
      let e = Error.tag (Error.of_exn e) ~tag:"app_harness: error escaped main" in
      Log.Global.error "%s" (Error.to_string_hum e);
      shutdown 1);
  (never_returns (Scheduler.go ()) : unit)
;;

let start_command
  (type a b)
  ~appname
  ~appdir_for_doc
  ~appdir
  ~(instance_arg : a Instance_arg.t)
  ~log_format
  (spec :
    (b, basedir:string -> instance:a -> mode:Mode.t -> unit Deferred.t) Command.Spec.t)
  (main : b)
  : Command.t
  =
  let readme () = sprintf "BASEDIR is by default %s/MODE" appdir_for_doc in
  let open Command.Spec in
  let start = start ~instance_arg in
  match instance_arg with
  | Optional ->
    let spec =
      spec
      ++ step (fun main -> start ~init_stds:true ~log_format ~appname ~main)
      ++ common_flags ~instance_arg ~appdir_for_doc ~appdir
      ++ step (fun k x -> k ~fg:x)
      +> flag "-fg" no_arg ~doc:" run in foreground, don't daemonize"
    in
    Command.basic_spec ~summary:("start " ^ appname) ~readme spec main
  | Required ->
    let spec =
      spec
      ++ step (fun main ~basedir ~instance ~mode ->
           start ~init_stds:true ~log_format ~appname ~main ~basedir ~instance ~mode)
      ++ common_flags ~instance_arg ~appdir_for_doc ~appdir
      ++ step (fun k x -> k ~fg:x)
      +> flag "-fg" no_arg ~doc:" run in foreground, don't daemonize"
    in
    Command.basic_spec ~summary:("start " ^ appname) ~readme spec main
;;

let stop_command
  (type a)
  ~appname
  ~appdir_for_doc
  ~appdir
  ~(instance_arg : a Instance_arg.t)
  =
  Command.basic_spec
    ~summary:("stop " ^ appname)
    (common_flags ~instance_arg ~appdir_for_doc ~appdir)
    (fun ~basedir ~instance ~mode:_ () ->
    let _, pid = Lock_file.read_exn ~instance_arg ~appname ~instance ~basedir in
    match Signal_unix.send Signal.term (`Pid pid) with
    | `Ok -> ()
    | `No_such_process -> failwithf !"Attempt to kill nonexistent pid %{Pid}" pid ())
;;

let status_command ~appname ~appdir_for_doc ~appdir ~instance_arg =
  Command.basic_spec
    ~summary:("status of " ^ appname)
    (common_flags ~instance_arg ~appdir_for_doc ~appdir)
    (fun ~basedir ~instance ~mode:_ () ->
    try
      let host, pid = Lock_file.read_exn ~instance_arg ~appname ~instance ~basedir in
      Core.printf "%s: RUNNING on host %s pid %d\n%!" appname host (Pid.to_int pid);
      Core_unix.exit_immediately 0
    with
    | exn ->
      Core.printf "%s: NOT RUNNING %s\n%!" appname (Exn.to_string exn);
      Core_unix.exit_immediately 1)
;;

let commands
  (type a)
  ~appname
  ~appdir_for_doc
  ~appdir
  ~(instance_arg : a Instance_arg.t)
  ~log_format
  ~start_spec
  ~start_main
  =
  [ ( "start"
    , start_command
        ~appname
        ~appdir_for_doc
        ~appdir
        ~instance_arg
        ~log_format
        start_spec
        start_main )
  ; "stop", stop_command ~appname ~appdir_for_doc ~appdir ~instance_arg
  ; "status", status_command ~appname ~appdir_for_doc ~appdir ~instance_arg
  ]
;;
