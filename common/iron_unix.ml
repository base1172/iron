open! Core
open! Async
open! Import
include Unix

let exec = Core_unix.exec
let stdin_isatty = Core_unix.(isatty stdin)
let stdout_isatty = Core_unix.(isatty stdout)
