open Core
open Async
open Import

let open_file file =
  match%bind Abspath.file_exists_exn file with
  | false -> return ()
  | true ->
    let elisp =
      sprintf
        "(let ((frame-to-use\n\
        \          (if (and (boundp 'Jane.Cr.dedicated-review-frame)\n\
        \                (frame-live-p Jane.Cr.dedicated-review-frame))\n\
        \              Jane.Cr.dedicated-review-frame\n\
        \              (selected-frame))))\n\
        \   (set-window-buffer\n\
        \      (frame-selected-window frame-to-use)\n\
        \      (find-file-noselect \"%s\")))"
        (Abspath.to_string file)
    in
    (match%map Process.run ~prog:"emacsclient" ~args:[ "-e"; elisp ] () with
     | Ok (_ : string) -> ()
     | Error e -> raise_s [%sexp "problem with emacs", (e : Error.t)])
;;
