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

val start
  :  init_stds:bool
  -> log_format:Log.Output.Format.t
  -> appname:string
  -> main:(basedir:string -> instance:string option -> mode:Mode.t -> unit Deferred.t)
  -> basedir:string
  -> instance:string option
  -> mode:Mode.t
  -> fg:bool
  -> unit
  -> unit

val commands
  :  appname:string
  -> appdir_for_doc:string
  -> appdir:string
  -> log_format:Log.Output.Format.t
  -> start_spec:
       ( 'a
       , basedir:string -> instance:string option -> mode:Mode.t -> unit Deferred.t )
       Command.Spec.t
  -> start_main:'a
  -> (string * Command.t) list
