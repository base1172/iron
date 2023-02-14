(** Just a file name, not a full path.

    A file name is a nonempty string and is not allowed to contain a '/' or '\000'. *)

open! Core
open! Import

type t

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

val alphabetic_compare : t -> t -> int

(** [default_review_compare] is like [alphabetic_compare], but has domain-specific rules
    based on file suffixes, so that e.g. [foo.mli] appears before [foo.ml]. *)
val default_review_compare : t -> t -> int

(** Special Unix filenames *)
val dot : t

val dotdot : t
val dot_fe : t
val scaffold_sexp : t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving hash]

    include Stable_without_comparator with type t := t
  end
end
