open! Core
open! Import

module type Stable = sig
  type model
  type comparator_witness

  module V1 : sig
    type t = model [@@deriving hash]

    include Stable_without_comparator with type t := t
    include Stringable.S with type t := t

    module Map : sig
      type 'a t = (model, 'a, comparator_witness) Map.t
      [@@deriving bin_io, compare, sexp, hash]
    end

    module Set : sig
      type t = (model, comparator_witness) Set.t [@@deriving bin_io, compare, sexp, hash]
    end
  end
end

module type Unstable = sig
  type t
  type comparator_witness

  include
    Identifiable.S with type t := t and type comparator_witness := comparator_witness

  include
    Comparable.S_common with type t := t and type comparator_witness := comparator_witness

  include Invariant.S with type t := t
  include Stringable.S with type t := t
  include Sexpable.S with type t := t
  include Binable.S with type t := t
  include Pretty_printer.S with type t := t
  include Hashable.S with type t := t

  module Map : sig
    include
      Core.Map.S with type Key.t = t and type Key.comparator_witness = comparator_witness

    val hash_fold_t : 'a Hash.folder -> 'a t Hash.folder
  end

  module Set : sig
    include
      Core.Set.S with type Elt.t = t and type Elt.comparator_witness = comparator_witness

    val hash_fold_t : Hash.state -> t -> Hash.state
    val hash : t -> int
  end
end

module type S = sig
  include Unstable

  module Stable :
    Stable with type model := t with type comparator_witness := comparator_witness
end

module type Validated_string = sig
  module type S = S
  module type Stable = Stable
  module type Unstable = Unstable

  module Make (_ : sig
    val module_name : string
    val check_valid : string -> unit Or_error.t
  end)
  () : S

  module Make_regex (_ : sig
    val module_name : string
    val regex : Regex.t
  end)
  () : S
end
