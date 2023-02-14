open! Core
open! Async
open! Import

let prod_directory = "/j/office/app/fe/prod"
let prod_bin_directory = Filename.concat prod_directory "bin"
let prod_etc_directory = Filename.concat prod_directory "etc"
let deployed_exe = Filename.concat prod_bin_directory "fe"
let deployed_hgrc = Filename.concat prod_etc_directory "hgrc"
let deployed_bashrc = Filename.concat prod_etc_directory "bashrc"
let deployed_check_obligations = Filename.concat prod_bin_directory "check-obligations"

let generic_deploy_arguments =
  Command.Spec.(
    step (fun f message remaining_arguments ->
      f ("-message" :: message :: remaining_arguments))
    +> flag "-message" (required string) ~doc:" message given to sink deploy"
    +> flag
         "--"
         ~doc:" pass the remaining arguments to sink deploy"
         (map_flag escape ~f:(Option.value ~default:[])))
;;

let fork_exec_wait ~prog ~args =
  Core_unix.waitpid_exn (Core_unix.fork_exec ~prog ~argv:(prog :: args) ())
;;

let generic_deploy ~remaining_arguments ~src ~dst =
  fork_exec_wait
    ~prog:"/j/office/app/sink/prod/bin/sink"
    ~args:
      ([ "deploy"; "file"; src; "-allow-non-inlined-libraries" ]
      @ List.map Iron_common.Std.Iron_config.deploy_offices ~f:(fun office ->
          sprintf "as-fe@sink.%s:%s" office dst)
      @ remaining_arguments)
;;

let check_exe_on_last_backup exe =
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
  fork_exec_wait ~prog:"bash" ~args:[ "-e"; "-u"; "-c"; command ]
;;

let check_invariants_of_most_recent_prod_backup =
  Command.basic_spec
    ~summary:"check the most recent backup of prod"
    Command.Spec.empty
    (fun () -> check_exe_on_last_backup Sys.executable_name)
;;

let deploy =
  Command.basic_spec
    ~summary:(sprintf "install the given executable to %s" deployed_exe)
    Command.Spec.(
      empty
      +> flag
           "-fe"
           (optional_with_default "self" Filename_unix.arg_type)
           ~doc:"(EXE|self|none) which executable to roll (defaults to self)"
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
      ++ generic_deploy_arguments)
    (fun exe hgrc bashrc no_backup_check remaining_arguments () ->
      let exe =
        match exe with
        | "none" -> None
        | "self" -> Some Sys.executable_name
        | file -> Some file
      in
      let exe_dir = Filename.dirname Sys.executable_name in
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
      if not no_backup_check then Option.iter exe ~f:check_exe_on_last_backup;
      List.iter
        [ exe, deployed_exe; hgrc, deployed_hgrc; bashrc, deployed_bashrc ]
        ~f:(fun (src_opt, dst) ->
          match src_opt with
          | None -> ()
          | Some src -> generic_deploy ~remaining_arguments ~src ~dst))
;;

let deploy_check_obligations =
  Command.basic_spec
    ~summary:(sprintf "install the given script to %s" deployed_check_obligations)
    Command.Spec.(
      empty +> anon ("file" %: Filename_unix.arg_type) ++ generic_deploy_arguments)
    (fun file remaining_arguments () ->
      fork_exec_wait ~prog:"bash" ~args:[ "-n"; file ];
      generic_deploy ~remaining_arguments ~src:file ~dst:deployed_check_obligations)
;;
