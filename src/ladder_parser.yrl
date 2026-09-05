Nonterminals routine rungs rung branches branch elems elem.
Terminals rnd bst nxb bnd name int_lit.
Rootsymbol routine.

%% `branch -> '$empty'` below also makes an empty *rung* derivable, so a leading
%% or trailing newline would otherwise materialise a phantom {rung, []}. Drop
%% those here; empty branch legs (a jumper) are kept and still pass power.
routine -> rungs : {routine, {rungs, [R || R = {rung, E} <- '$1', E =/= []]}}.

rungs -> rung : ['$1'].

rungs -> rung rnd rungs : ['$1' | '$3'].

rung -> branch : {rung, '$1'}.

branch -> elems : '$1'.

%% A branch leg with no elements is a jumper: it passes power unconditionally.
%% This is also what lets a rung be empty, which is how leading, trailing and
%% repeated newlines become legal — see the filter on `routine` above.
branch -> '$empty' : [].

elems -> elem : ['$1'].

elems -> elem elems : ['$1' | '$2'].

%% A name or int_lit elem is the lexer token itself, {Kind, Line, Value}: the
%% line is kept so that later stages can cite a location. Nothing downstream
%% reads it yet, and nothing downstream may drop it. A branches elem is
%% {branches, Legs} and carries no line of its own -- the bst token's line is
%% dropped here. Widening that node is a separate decision (PLAN.md M1-2).
elem -> int_lit : '$1'.

elem -> name : '$1'.

elem ->  bst branches bnd : {branches, '$2'}.

branches -> branch : ['$1'].

branches -> branch nxb branches : ['$1' | '$3'].

