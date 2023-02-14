open! Core
open! Import

module T = struct
  type t = Re2.Stable.V2.t [@@deriving bin_io, compare]

  let of_string s = Re2.create (String.concat [ "\\A"; s; "\\z" ]) |> ok_exn

  let to_string re =
    let s = Re2.pattern re in
    String.slice s 2 (String.length s - 2)
  ;;

  let module_name = "Iron_obligations.Whole_regexp"
  let hash t = String.hash (to_string t)
  let hash_fold_t state t = String.hash_fold_t state (to_string t)
end

include T

include Identifiable.Make (struct
  include T
  include Sexpable.Of_stringable (T)
end)

let matches = Re2.matches
let rewrite = Re2.rewrite
let valid_rewrite_template = Re2.valid_rewrite_template
