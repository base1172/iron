open Core
module Stable = Time_ns.Stable

module type Iron_time = sig
  include module type of struct
      include Time_ns_unix
    end
    with module Stable := Time_ns_unix.Stable

  module Stable : sig
    module V1_round_trippable : Stable_without_comparator with type t = t
  end
end
