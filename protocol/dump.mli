open! Core.Std
open! Import

module Which_user_info : sig
  type t =
    | Aliases
    | Existing_users
    | Typos
    | Valid_users
  [@@deriving sexp_of]
end

module Action : sig
  type t =
    | Archived_features_cache   of [ `Stats
                                   | `Ids_and_feature_paths
                                   | `Value of Feature_id.t
                                   ]
    | Bookmarks_without_feature of Remote_repo_path.t option
                                   * [ `All_users | `User of User_name.t ]
    | Build_info
    | Event_subscriptions
    | Feature                   of Feature_path.t
    | Hash_consing_cache        of Hash_consing.What_to_dump.t
    | Push_events               of Push_events.What_to_dump.t
    | Review_analysis           of Feature_path.t
    | Review_manager            of Feature_path.t * [ `All_users | `User of User_name.t ]
    | Review_lines              of Feature_path.t * [ `All_users | `User of User_name.t ]
    | State
    | Timed_event_table
    | Unclean_workspaces        of [ `All_users | `User of User_name.t ]
    | User_info                 of Which_user_info.t
    | Version
    | Worker_cache              of Worker_cache.What_to_dump.t
  [@@deriving sexp_of]
end

module Reaction : sig
  type t = Sexp.t [@@deriving sexp_of]
end

include Iron_versioned_rpc.S
  with type action   = Action.t
  with type reaction = Reaction.t