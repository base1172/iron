module Stable = struct

  open Import_stable

  module Action = struct
    module V3 = struct
      include Maybe_archived_feature_spec.V2

      let to_model t = t
    end

    module V2 = struct
      include Maybe_archived_feature_spec.V1

      let to_model t = V3.to_model (Maybe_archived_feature_spec.V1.to_v2 t)
    end

    module V1 = struct
      type t =
        { feature_path : Feature_path.V1.t
        }
      [@@deriving bin_io]

      let to_model { feature_path } =
        V2.to_model (V2.existing_feature_path feature_path)
      ;;
    end

    module Model = V3
  end

  module Reaction = struct
    module V1 = struct
      type t =
        { description : string
        }
      [@@deriving bin_io, sexp]

      let of_model t = t
    end

    module Model = V1
  end
end

include Iron_versioned_rpc.Make
    (struct let name = "feature-description" end)
    (struct let version = 3 end)
    (Stable.Action.V3)
    (Stable.Reaction.V1)

include Register_old_rpc
    (struct let version = 2 end)
    (Stable.Action.V2)
    (Stable.Reaction.V1)

include Register_old_rpc
    (struct let version = 1 end)
    (Stable.Action.V1)
    (Stable.Reaction.V1)

module Action   = Stable.Action.  Model
module Reaction = Stable.Reaction.Model
