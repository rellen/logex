Definitions.

INT = [0-9]+

NAME = [a-zA-Z_][a-zA-Z0-9_]*
WHITESPACE = [\s\t\r]
BST = (bst)
NXB = (nxb)
BND = (bnd)
RND = (\r?\n)

Rules.

{BST} : {token, {bst, TokenLine}}.
{NXB} : {token, {nxb, TokenLine}}.
{BND} : {token, {bnd, TokenLine}}.
%% A run of newlines and the whitespace between them is one rung delimiter, so
%% blank lines and indentation do not reach the grammar.
({WHITESPACE}*{RND})+ : {token, {rnd, TokenLine}}.
{INT} : {token, {int_lit, TokenLine, list_to_integer(TokenChars)}}.
{NAME} : {token, {name, TokenLine, list_to_string(TokenChars)}}.
{WHITESPACE}+ : skip_token.

Erlang code.

list_to_string(List) ->
  unicode:characters_to_binary(List).
