module Stable = struct
  open! Import_stable

  module Action = struct
    module V1 = struct
      type t = { for_ : User_name.V1.t } [@@deriving bin_io, sexp]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 2d35c5ff133d024c8a5125240951daca |}]
      ;;

      let to_model t = t
    end

    module Model = V1
  end

  module Reaction = struct
    module V1 = Unit
    module Model = V1
  end
end

include
  Iron_versioned_rpc.Make
    (struct
      let name = "may-modify-others-catch-up"
    end)
    (struct
      let version = 1
    end)
    (Stable.Action.V1)
    (Stable.Reaction.V1)

module Action = Stable.Action.Model
module Reaction = Stable.Reaction.Model
