module Stable = struct
  open! Core.Core_stable
  open! Import_stable

  module V1 = struct
    type t =
      { base : Rev.Stable.V1.t
      ; tip : Rev.Stable.V1.t
      }
    [@@deriving bin_io, sexp]

    let%expect_test _ =
      print_endline [%bin_digest: t];
      [%expect {| 58eeef7d0a4b08bd3182385171508ce1 |}]
    ;;

    module Compare_by_hash = struct
      type nonrec t = t =
        { base : Rev.Compare_by_hash.t
        ; tip : Rev.Compare_by_hash.t
        }
      [@@deriving compare, hash]
    end

    include (Compare_by_hash : module type of Compare_by_hash with type t := t)
  end
end

open! Core
open! Import
include Stable.V1
include Comparable.Make (Stable.V1)
include Hashable.Make (Stable.V1)
