-module(bell_validator_ffi).
-export([halt/1, arguments/0]).

halt(Code) -> erlang:halt(Code).

arguments() -> [unicode:characters_to_binary(A) || A <- init:get_plain_arguments()].
