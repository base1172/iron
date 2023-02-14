open! Core
open! Async

let with_temp_file ?file f =
  let base =
    match file with
    | Some file -> Filename.basename file
    | None -> "tmp"
  in
  let prefix, suffix =
    match String.rsplit2 ~on:'.' base with
    | Some (base, ext) -> base, ext
    | None -> base, ".tmp"
  in
  let file = Filename_unix.temp_file prefix suffix in
  Monitor.protect ~finally:(fun () -> Unix.unlink file) (fun () -> f file)
;;

let get_editor () =
  let get_gen env_vars defaults =
    let env_var_programs = List.filter_map env_vars ~f:Sys.getenv in
    let programs = env_var_programs @ defaults in
    let rec first_valid = function
      | [] -> None
      | p :: ps ->
        (* ignore options given in env vars (e.g., emacsclient -c). String.split always
         returns list of at least 1 element. *)
        let p_no_opts = String.split ~on:' ' p |> List.hd_exn in
        (match Shell.which p_no_opts with
         | Some _ -> Some p
         | None -> first_valid ps)
    in
    first_valid programs
  in
  get_gen [ "EDITOR"; "VISUAL" ] [ "vim"; "emacs"; "nano" ]
;;

let invoke_editor ?(tmpfile = "tmp") text =
  let editor = Option.value ~default:"emacs" (get_editor ()) in
  with_temp_file ~file:tmpfile (fun file ->
    let%bind () = Writer.save file ~contents:text in
    match%bind Unix.system (sprintf "%s %s" editor file) with
    | Ok () ->
      let%map contents = Reader.file_contents file in
      Ok contents
    | stat -> error "Error editing text" stat [%sexp_of: Unix.Exit_or_signal.t] |> return)
;;
