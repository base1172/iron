module Stable = struct
  open! Import_stable

  module Action = struct
    module V2 = struct
      type t = { feature_path : Feature_path.V1.t } [@@deriving bin_io, fields, sexp]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 82e9dd83ba682394b6a7532a1bdf9e67 |}]
      ;;

      let to_model t = t
    end

    module Model = V2
  end

  module Reaction = struct
    module V1 = Unit
    module Model = V1
  end
end

include
  Iron_versioned_rpc.Make
    (struct
      let name = "is-releasable"
    end)
    (struct
      let version = 2
    end)
    (Stable.Action.V2)
    (Stable.Reaction.V1)

module Action = Stable.Action.Model
module Reaction = Stable.Reaction.Model
