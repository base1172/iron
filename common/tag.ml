open! Core.Std
open! Import

include Validated_string.Make_regex (struct
    let module_name = "Iron_common.Tag"
    let regex = Regex.user_name
  end) ()