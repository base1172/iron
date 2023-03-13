open! Core
open! Async
open! Import

module Mode : sig
  type t =
    [ `Prod
    | `Dev
    ]

  include Comparable.S with type t := t
  include Stringable.S with type t := t
  include Sexpable.S with type t := t
end

module Instance_arg : sig
  type 'a t =
    | Optional : string option t
    | Required : string t
end

val start
  :  instance_arg:'a Instance_arg.t
  -> init_stds:bool
  -> log_format:Log.Output.Format.t
  -> appname:string
  -> main:(basedir:string -> instance:'a -> mode:Mode.t -> unit Deferred.t)
  -> basedir:string
  -> instance:'a
  -> mode:Mode.t
  -> fg:bool
  -> unit
  -> unit

val commands
  :  appname:string
  -> appdir_for_doc:string
  -> appdir:string
  -> instance_arg:'a Instance_arg.t
  -> log_format:Log.Output.Format.t
  -> start_spec:
       ( 'b
       , basedir:string -> instance:'a -> mode:Mode.t -> unit Deferred.t )
       Command.Spec.t
  -> start_main:'b
  -> (string * Command.t) list
