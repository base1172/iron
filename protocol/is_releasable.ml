module Stable = struct

  open Import_stable

  module Action = struct
    module V2 = struct
      type t =
        { feature_path  : Feature_path.V1.t
        }
      [@@deriving bin_io, fields, sexp]

      let to_model t = t
    end
  end

  module Reaction = struct
    module V1 = Unit
  end

end

include Iron_versioned_rpc.Make
    (struct let name = "is-releasable" end)
    (struct let version = 2 end)
    (Stable.Action.V2)
    (Stable.Reaction.V1)

module Action   = Stable.Action.V2
module Reaction = Stable.Reaction.V1
