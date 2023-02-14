(** A path in a repo, relative to the repo root.

    This is like a [Relpath], but the types are not equal. *)

open! Core
open! Import

type t [@@deriving sexp_of]

include Identifiable with type t := t
include Invariant.S with type t := t

module Map : sig
  module Key : sig
    type nonrec t = t [@@deriving bin_io, sexp]
    type nonrec comparator_witness = comparator_witness

    val comparator : (t, comparator_witness) Comparator.t
  end

  include Core.Map.S with module Key := Key
  include Core.Binable.S1 with type 'a t := 'a t

  val hash_fold_t : 'a Hash.folder -> 'a t Hash.folder
end

val of_string : string -> t
val root : t
val chop_prefix : prefix:t -> t -> Relpath.t Or_error.t
val is_prefix : prefix:t -> t -> bool
val split_dir_file_exn : t -> t * File_name.t
val of_list : File_name.t list -> t
val parts : t -> File_name.t list
val append : t -> Relpath.t -> t
val extend : t -> File_name.t -> t
val parent : t -> t option
val parent_exn : t -> t
val of_relpath : Relpath.t -> t
val to_relpath : t -> Relpath.t
val default_review_compare : t -> t -> int
val low_review_file : Build_projection_name.t -> t

module Stable : sig
  module V1 : sig
    include Stable_without_comparator with type t = t

    val hash_fold_t : t Hash.folder
    val hash : t -> int
  end
end
