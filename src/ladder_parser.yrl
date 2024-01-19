Nonterminals rung branches branch elems elem.
Terminals bst nxb bnd name int_lit.
Rootsymbol rung.

rung -> branch : {rung, '$1'}.

branch -> elems : '$1'.

elems -> elem : ['$1'].

elems -> elem elems : ['$1' | '$2'].

elem -> int_lit : {int_lit, extract_token('$1')}.

elem -> name : {name, extract_token('$1')}.

elem ->  bst branches bnd : {branches, '$2'}.

branches -> branch : ['$1'].

branches -> branch nxb branches : ['$1' | '$3'].


Erlang code.

extract_token({_Token, _Line, Value}) -> Value.
