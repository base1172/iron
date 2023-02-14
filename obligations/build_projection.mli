(** Build-projection records. *)

open! Core
open! Import

type t = private
  { name : Build_projection_name.t
  ; default_scrutiny : Scrutiny.t
  ; require_low_review_file : bool
  }
[@@deriving compare, fields, sexp_of]

val create
  :  name:Build_projection_name.t
  -> default_scrutiny:Scrutiny.t
  -> require_low_review_file:bool
  -> t

module Stable : sig
  module V2 : sig
    type nonrec t = t [@@deriving hash]

    include Stable_without_comparator with type t := t
  end
end
