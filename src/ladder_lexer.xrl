Definitions.

INT = [0-9]+

NAME = [a-zA-Z_][a-zA-z0-9_]+
WHITESPACE = [\s\t\n\r]
BST = (bst)
NXB = (nxb)
BND = (bnd)

Rules.

{BST} : {token, {bst, TokenLine}}.
{NXB} : {token, {nxb, TokenLine}}.
{BND} : {token, {bnd, TokenLine}}.
{INT} : {token, {int_lit, TokenLine, list_to_integer(TokenChars)}}.
{NAME} : {token, {name, TokenLine, list_to_string(TokenChars)}}.
{WHITESPACE}+ : skip_token.

Erlang code.

list_to_string(list) ->
  unicode:characters_to_binary(list).
