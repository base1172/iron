open Core
open Import
include Validated_string_intf

module Make (M : sig
  val module_name : string
  val check_valid : string -> unit Or_error.t
end)
() : S = struct
  open M

  module Stable = struct
    module V1 = struct
      module T = struct
        module Unshared = struct
          type t = string [@@deriving bin_io, compare, sexp, hash]

          let module_name = module_name
        end

        include Hash_consing.Stable.Make_stable_private (Unshared) ()

        let to_string (t : t) = (t :> string)

        let of_string string =
          match check_valid string with
          | Ok () -> shared_t string
          | Error error ->
            raise_s
              [%sexp
                "invalid", (module_name : string), (string : string), (error : Error.t)]
        ;;

        let caller_identity =
          Bin_prot.Shape.Uuid.of_string "4efea033-1884-4812-9e6e-f1dc3a662315"
        ;;
      end

      module Unstable = Identifiable.Make (struct
        include T
        include Binable.Of_stringable_with_uuid (T)
        include Sexpable.Of_stringable (T)
      end)

      module T_with_comparator = struct
        include T

        type comparator_witness = Unstable.comparator_witness

        let comparator = Unstable.comparator
      end

      include T

      module Comparable = struct
        include Core.Core_stable.Comparable.V1.Make (T_with_comparator)
        module Unstable = Core.Comparable.Make_using_comparator (T_with_comparator)
      end

      module Map = struct
        include Comparable.Map
        include Comparable.Unstable.Map.Provide_hash (T_with_comparator)
        include Comparable.Unstable.Map.Provide_bin_io (T_with_comparator)
      end

      module Set = struct
        include Comparable.Set
        include Comparable.Unstable.Set.Provide_hash (T_with_comparator)
        (* let module_name = M.module_name ^ ".Set" *)
        (* include Hash_consing.Stable.Make_stable_public (T) () *)
      end

      include Core.Core_stable.Hashable.V1.Make (T_with_comparator)
    end
  end

  include Stable.V1.T
  include Stable.V1.Unstable

  module Map = struct
    include Stable.V1.Unstable.Map
    include Stable.V1.Unstable.Map.Provide_hash (Stable.V1.T_with_comparator)
  end

  module Set = struct
    include Stable.V1.Unstable.Set
    include Stable.V1.Unstable.Set.Provide_hash (Stable.V1.T_with_comparator)
  end

  let invariant (t : t) = assert (is_ok (check_valid (t :> string)))
end

module Make_regex (M : sig
  val module_name : string
  val regex : Regex.t
end)
() =
  Make
    (struct
      include M

      let check_valid string =
        if Regex.matches regex string
        then Ok ()
        else error "does not match regex" regex [%sexp_of: Regex.t]
      ;;
    end)
    ()

module For_testing = struct
  include
    Make_regex
      (struct
        let module_name = "For_testing"
        let regex = Regex.create_exn ""
      end)
      ()

  (* This test can't go into the Stable module above, because that's in the functor and
     expect tests must be run in the file where they are defined. *)
  let%expect_test _ =
    print_endline [%bin_digest: t];
    [%expect {| d9a8da25d5656b016fb4dbdc2e4197fb |}]
  ;;
end
