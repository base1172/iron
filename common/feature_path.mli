open! Core.Std
open! Import

type t [@@deriving sexp_of]

include Comparable.S_binable with type t := t
include Hashable.S           with type t := t
include Invariant. S         with type t := t
include Stringable           with type t := t

val of_string_or_error : string -> t Or_error.t

(** [parts (of_string "a/b/c") = [ "a"; "b"; "c" ]]. *)
val parts : t -> Feature_name.t list
val to_relpath : t -> Relpath.t

(** [of_parts_exn [ "a"; "b"; "c" ] = "a/b/c"].  [of_parts_exn []] raises. *)
val of_parts_exn : Feature_name.t list -> t

val num_parts : t -> int
(* [is_root t] <=> [num_parts t = 1] *)
val is_root   : t -> bool
val root      : t -> Feature_name.t
val root_path : t -> t
val of_root   : Feature_name.t -> t

val is_ancestor : ancestor:t -> descendant:t -> bool

val as_root : t -> Feature_name.t Or_error.t

val extend : t -> Feature_name.t -> t

val parent              : t -> t Or_error.t
val basename            : t -> Feature_name.t
val parent_and_basename : t -> t option * Feature_name.t

(** [compress_parent_exn t] omits the parent part from [t], raising if [num_parts t < 2].
    E.g.:

    {[
      compress_parent_exn (of_string "a/b/c/d/e") = of_string "a/b/c/e"
    ]}
*)
val compress_parent_exn : t -> t

val check_renameable : from:t -> to_:t -> unit Or_error.t

(** A "partial name" of a feature path is a suffix of a feature path beginning either
    after a slash or at the start of the feature path.  [unstage (match_ ~prefix of_what)
    t] checks if [prefix] is a prefix of either a partial name of [t] or the full [t] and
    ends in the final feature name in [t].  If the match succeeds, the result is the
    suffix of [t] starting with [prefix].

    The staging is because [match_] creates a [Regex] in the first stage. *)
val match_
  :  prefix : string
  -> [ `Of_partial_name | `Of_full_name ]
  -> (t -> string option) Lazy.t

val complete
  :  iter_features:(f:(t -> unit) -> unit)
  -> prefix:string
  -> [ `Of_partial_name | `Of_full_name ]
  -> string list

module Stable : sig
  module V1 : Stable_without_comparator with type t = t
end
