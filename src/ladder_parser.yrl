Nonterminals routine rungs rung branches branch elems elem.
Terminals rnd bst nxb bnd name int_lit.
Rootsymbol routine.

routine -> rungs : {routine, {rungs, '$1'}}.

rungs -> rung : ['$1'].

rungs -> rung rnd rungs : ['$1' | '$3'].

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
