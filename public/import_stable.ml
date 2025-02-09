include (
  Core.Core_stable :
    module type of Core.Core_stable
      with module String := Core.Core_stable.String
      with module Time := Core.Core_stable.Time)

include Iron_common.Stable
include Iron_hg.Stable
module Fn = Core.Fn
module List = Core.List

module Unit = struct
  type t = unit [@@deriving bin_io, sexp]

  let of_model t = t
  let to_model t = t
end
