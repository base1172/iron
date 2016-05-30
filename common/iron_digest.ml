module Stable = struct
  open! Core.Stable
  module Hash_consing = Hash_consing.Stable

  module V1 = struct

    module Unshared = struct
      type t = string [@@deriving compare]

      let hash =
        Core.Std.String.hash
      ;;

      let module_name = "Iron_common.Digest"

      include Binable.Of_stringable.V1 (struct
          type nonrec t = t
          let of_string t = t
          let to_string t = t
        end)

      include Sexpable.Of_stringable.V1 (struct
          type nonrec t = t
          let of_string = Digest.from_hex
          let to_string = Digest.to_hex
        end)

    end
    include Hash_consing.Make_stable_private (Unshared) ()
  end
end

open! Core.Std
open! Import

module T = Stable.V1
include T
include Comparable.Make (T)
include Hashable.Make (T)

let invariant (_ : t) = ()

let create str = Digest.string str |> shared_t

let of_empty_string = create ""
