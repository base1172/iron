open! Core
module Rule = Patdiff.Format.Rule
module Rules = Patdiff.Format.Rules
module Style = Patdiff.Format.Style
module Color = Patdiff.Format.Color

type t = Patdiff.Format.Rules.t

let outer_line_change ~style ~name text color =
  let pre = Rule.Affix.create ~styles:Style.[ Bold; Bg color; Fg Color.White ] text in
  ignore name;
  (* Rule.create ~pre style ~name *)
  Rule.create ~pre style
;;

let word_change ~name color =
  ignore name;
  (* Rule.create Style.([ Fg color ]) ~name *)
  Rule.create Style.[ Fg color ]
;;

let inner_default = Patdiff.Format.Rules.default

let outer_default =
  { inner_default with
    Rules.line_prev = outer_line_change ~name:"line_old" ~style:[] "--" Color.Magenta
  ; line_next = outer_line_change ~name:"line_new" ~style:[] "++" Color.Cyan
  ; word_prev = word_change ~name:"word_old" Color.Magenta
  ; word_next = word_change ~name:"word_new" Color.Cyan
  }
;;

(* This is rather hacky, mainly for historical reason. We want to support loading
   existing config files from patdiff *)
let t_of_sexp sexp =
  let config = Patdiff.Configuration.On_disk.t_of_sexp sexp in
  Patdiff.Configuration.parse config |> fun t -> t.Patdiff.Configuration.rules
;;
