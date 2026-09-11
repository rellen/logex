Definitions.

INT = [0-9]+

NAME = [a-zA-Z_][a-zA-Z0-9_]*
WHITESPACE = [\s\t\r]
%% Punctuation, not words: `bst`/`nxb`/`bnd` were drawn from the same character set
%% as NAME, so leex's maximal munch swallowed them into an adjacent identifier and a
%% missing space silently turned OR into AND (PLAN.md §4·B1). Every metacharacter is
%% escaped -- an unescaped `BST = (()` is `bad regexp 'unterminated ('`, and a
%% half-escaped variant is the dangerous one.
BST = (\()
NXB = (\|)
BND = (\))
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
