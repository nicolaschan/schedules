-module(bell_validator_ffi).
-export([arguments/0]).

arguments() -> [unicode:characters_to_binary(A) || A <- init:get_plain_arguments()].
