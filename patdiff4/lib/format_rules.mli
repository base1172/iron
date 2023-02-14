type t = Patdiff.Format.Rules.t [@@deriving of_sexp]

(** [inner] is the default configuration for patdiff.  [outer] is used for ddiffs to
    compare two inner diffs *)
val inner_default : t

val outer_default : t
