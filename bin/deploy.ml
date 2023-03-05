open! Core
open! Async
open! Import

let prod_directory = "/j/office/app/fe/prod"
let prod_bin_directory = Filename.concat prod_directory "bin"
let prod_etc_directory = Filename.concat prod_directory "etc"
let deployed_exe = Filename.concat prod_bin_directory "fe"
let deployed_hydra = Filename.concat prod_bin_directory "hydra"
let deployed_hgrc = Filename.concat prod_etc_directory "hgrc"
let deployed_bashrc = Filename.concat prod_etc_directory "bashrc"
let deployed_check_obligations = Filename.concat prod_bin_directory "check-obligations"

let generic_deploy_arguments =
  Command.Spec.(
    step (fun f remaining_arguments -> f remaining_arguments)
    +> flag
         "--"
         ~doc:" pass the remaining arguments to sink deploy"
         (map_flag escape ~f:(Option.value ~default:[])))
;;

let maybe_run ~dry_run ~cmd =
  if dry_run
  then (
    Log.Global.raw "%s" (Shell.Process.to_string cmd);
    Deferred.Or_error.ok_unit)
  else
    Deferred.create (fun ivar ->
      Or_error.try_with (fun () -> Shell.Process.run cmd Shell.Process.discard)
      |> Ivar.fill ivar)
;;

let generic_deploy ~dry_run ~hosts ~user ~remaining_arguments ~src ~dst =
  let cmd =
    Shell.Process.cmd
      "rsync"
      ([ "-rltz"; sprintf "--chown=%s" user; src ]
      @ List.map hosts ~f:(fun office -> sprintf "%s@%s:%s" user office dst)
      @ remaining_arguments)
  in
  maybe_run ~dry_run ~cmd
;;

let check_exe_on_last_backup ~dry_run exe =
  let command =
    sprintf
      "dir=$(mktemp --tmpdir -d);\n\
       trap 'rm -rf -- $dir' EXIT INT QUIT\n\
       cd $dir\n\
       echo >&2 Downloading last backup\n\
       ssh %s '\n\
      \  cd /j/office/app/fe/prod/backups;\n\
      \  backup=$(ls -1 export-dir-backup.*.tar.xz | sort -g | tail -n 1)\n\
      \  echo >&2 $backup\n\
      \  cat $backup\n\
       ' > backup.tar.xz\n\
       tar -xJf backup.tar.xz\n\
       echo >&2 Checking invariants\n\
       %s internal invariant server-state check-backup-in $PWD/export\n"
      Fe_config.backup_host
      exe
  in
  let cmd = Shell.Process.cmd "bash" [ "-e"; "-u"; "-c"; command ] in
  maybe_run ~dry_run ~cmd
;;

let check_invariants_of_most_recent_prod_backup =
  Command.async_spec_or_error
    ~summary:"check the most recent backup of prod"
    Command.Spec.(
      empty
      +> flag
           "-dry-run"
           no_arg
           ~doc:
             " don't deploy, just print the operations that would be performed to stdout")
    (fun dry_run () -> check_exe_on_last_backup ~dry_run Sys.executable_name)
;;

let deploy =
  let exe_dir = Filename.dirname Sys.executable_name in
  Command.async_spec_or_error
    ~summary:(sprintf "install the given executable to %s" deployed_exe)
    Command.Spec.(
      empty
      +> flag
           "-fe"
           (optional_with_default "self" Filename_unix.arg_type)
           ~doc:"(EXE|self|none) which executable to roll (defaults to self)"
      +> flag
           "-hydra"
           (optional_with_default (exe_dir ^/ "hydra.exe") Filename_unix.arg_type)
           ~doc:"(EXE|none) which hydra executable to roll (defaults to hydra.exe)"
      +> flag
           "-hgrc"
           (optional_with_default "default" Filename_unix.arg_type)
           ~doc:"(HGRC|default|none) which hgrc to roll"
      +> flag
           "-bashrc"
           (optional_with_default "default" Filename_unix.arg_type)
           ~doc:"(BASHRC|default|none) which bashrc to roll"
      +> flag
           "-no-backup-check"
           no_arg
           ~doc:
             " do not check the invariants of the last backup with the exe about to be \
              rolled"
      +> flag
           "-dry-run"
           no_arg
           ~doc:
             " don't deploy, just print the operations that would be performed to stdout"
      +> flag
           "-hosts"
           (optional_with_default
              Iron_common.Std.Iron_config.deploy_offices
              (Arg_type.comma_separated string))
           ~doc:"HOSTS hosts to deploy on"
      +> flag
           "-user"
           (optional_with_default "as-fe" string)
           ~doc:"USER username to deploy as (default: as-fe)"
      ++ generic_deploy_arguments)
    (fun exe hydra hgrc bashrc no_backup_check dry_run hosts user remaining_arguments () ->
      let exe =
        match exe with
        | "none" -> None
        | "self" -> Some Sys.executable_name
        | file -> Some file
      in
      let hydra =
        match hydra with
        | "none" -> None
        | file -> Some file
      in
      let hgrc =
        match hgrc with
        | "none" -> None
        | "default" -> Some (exe_dir ^/ "../hg/hgrc")
        | file -> Some file
      in
      let bashrc =
        match bashrc with
        | "none" -> None
        | "default" -> Some (exe_dir ^/ "bashrc")
        | file -> Some file
      in
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        if no_backup_check
        then Deferred.Or_error.ok_unit
        else (
          match exe with
          | None -> Deferred.Or_error.ok_unit
          | Some exe -> check_exe_on_last_backup ~dry_run exe)
      in
      Deferred.Or_error.List.iter
        [ exe, deployed_exe
        ; hydra, deployed_hydra
        ; hgrc, deployed_hgrc
        ; bashrc, deployed_bashrc
        ]
        ~f:(fun (src_opt, dst) ->
          match src_opt with
          | None -> Deferred.Or_error.ok_unit
          | Some src ->
            generic_deploy ~dry_run ~hosts ~user ~remaining_arguments ~src ~dst))
;;

let deploy_check_obligations =
  Command.async_spec_or_error
    ~summary:(sprintf "install the given script to %s" deployed_check_obligations)
    Command.Spec.(
      empty
      +> flag
           "-dry-run"
           no_arg
           ~doc:
             " don't deploy, just print the operations that would be performed to stdout"
      +> flag
           "-hosts"
           (optional_with_default
              Iron_common.Std.Iron_config.deploy_offices
              (Arg_type.comma_separated string))
           ~doc:"HOSTS hosts to deploy on"
      +> flag
           "-user"
           (optional_with_default "as-fe" string)
           ~doc:"USER username to deploy as (default: as-fe)"
      +> anon ("file" %: Filename_unix.arg_type)
      ++ generic_deploy_arguments)
    (fun dry_run hosts user file remaining_arguments () ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () = maybe_run ~dry_run ~cmd:(Shell.Process.cmd "bash" [ "-n"; file ]) in
      generic_deploy
        ~dry_run
        ~hosts
        ~user
        ~remaining_arguments
        ~src:file
        ~dst:deployed_check_obligations)
;;
