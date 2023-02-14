module Stable = struct
  open! Core.Core_stable
  module Hash_consing = Hash_consing.Stable

  module V1 = struct
    module Unshared = struct
      type t = Core.Md5.Stable.V1.t [@@deriving compare, hash, sexp]

      let module_name = "Iron_common.Digest"

      include Binable.Of_sexpable.V2 (struct
        type nonrec t = t [@@deriving sexp]

        let caller_identity =
          Bin_prot.Shape.Uuid.of_string "842b2322-bc9a-4358-ad8b-3acc705604f8"
        ;;
      end)
    end

    include Hash_consing.Make_stable_private (Unshared) ()

    let%expect_test _ =
      print_endline [%bin_digest: t];
      [%expect {| d9a8da25d5656b016fb4dbdc2e4197fb |}]
    ;;
  end
end

open! Core
open! Import
module T = Stable.V1
include T
include Comparable.Make (T)
include Hashable.Make (T)

let invariant (_ : t) = ()
let create str = Md5.digest_string str |> shared_t
let of_empty_string = create ""
