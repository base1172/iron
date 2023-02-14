open! Core
open! Import

(** [t] is exposed just in order to create some stats for debugging purposes *)
type t [@@deriving sexp_of]

module Set_stats : sig
  type t = private
    { table_length : int
    ; number_of_entries : int
    ; sum_of_bucket_lengths : int
    ; smallest_bucket_length : int
    ; median_bucket_length : int
    ; biggest_bucket_length : int
    }
  [@@deriving fields, sexp_of]
end

val the_one_and_only : unit -> t
val stats : t -> Sexp.t
val detailed_stats : t -> (string * Set_stats.t) list

module Module_name : sig
  type t = string [@@deriving sexp_of]

  val module_name_without_libname : t -> t
end

module What_to_dump : sig
  type t =
    [ `Stats
    | `Values
    | `Module_values of Module_name.t
    | `Module_hash_data of Module_name.t
    ]
  [@@deriving sexp_of]

  val require_admin_privileges : t -> bool
end

val dump : t -> What_to_dump.t -> Sexp.t

module type Unshared = sig
  type t [@@deriving compare, sexp_of, hash]

  val module_name : Module_name.t
end

module type S = sig
  type t [@@deriving compare, sexp_of]

  val shared_t : t -> t
  val unshared_t : t -> t
end

module Make (X : Unshared) () : S with type t = X.t

module Make_binable (X : S) (T : Binable.S with type t = X.t) :
  Binable.S with type t := T.t

module Make_sexpable (X : S) (T : Sexpable.S with type t = X.t) :
  Sexpable.S with type t := T.t

module Make_stringable (X : S) (T : Stringable.S with type t = X.t) :
  Stringable.S with type t := T.t

module Make_hashable
  (X : S)
  (T : sig
    type t

    include Binable.S with type t := t
    include Hashtbl.Key with type t := t
  end
  with type t = X.t) : Hashable.Stable.V1.S with type key := T.t

module Stable : sig
  module type Shared = sig
    type x
    type t [@@deriving hash]

    val shared_t : x -> t
    val unshared_t : t -> x

    include Unshared with type t := t
    include Equal.S with type t := t
    include Binable.S with type t := t
    include Sexpable.S with type t := t
    include Hashable.Stable.V1.S with type key := t
    module S : S with type t = t
  end

  module Make_stable_private (X : sig
    include Unshared
    include Binable.S with type t := t
    include Sexpable.S with type t := t
    include Hashtbl.Key with type t := t
  end)
  () : sig
    type t = private X.t

    include Shared with type x := X.t and type t := t
  end

  module Make_stable_public (X : sig
    include Unshared
    include Binable.S with type t := t
    include Sexpable.S with type t := t
    include Hashtbl.Key with type t := t
  end)
  () : sig
    include Shared with type x := X.t and type t := X.t
  end
end
