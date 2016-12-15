module Stable = struct

  open Import_stable

  module Action = struct
    module V1 = struct
      type t =
        | Get
        | Clear
      [@@deriving bin_io, sexp]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 7e7b03b96641153ddc31e2a1a5152808 |}]
      ;;

      let to_model t = t
    end
  end

  module Reaction = struct
    module V1 = Unit
  end
end

include Iron_versioned_rpc.Make
    (struct let name = "with-cached-attributes-errors" end)
    (struct let version = 1 end)
    (Stable.Action.V1)
    (Stable.Reaction.V1)

module Action   = Stable.Action.  V1
module Reaction = Stable.Reaction.V1
