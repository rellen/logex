# Forms that the pages do not have

This page is for a person who writes a page of the logex documentation. It gives the
forms of the older documents that a page does not have. The
[style guide](style-guide.md) gives the other rules for the words.

## The house manner

The older documents of this repository have a house manner. A new page does not have it.
This table gives examples of the manner. It is not a complete list.

| Do not write | Write |
|---|---|
| `a process of its own`, `a module all its own` | a separate process, a separate module |
| `is told`, `told its count first` | "logex reports", "the message says" |
| `held to`, `pinned whole`, `the test pins the message` | "the test compares A with B", "must be the same as" |
| `each a report`, `each with its line`, `every one reported`, `one line a page` | A full sentence: "Each step returns a report." |
| `as built`, `as written`, `as shipped`, `as it stands` | Say what the thing is |
| `the one table`, `the one place` | 1 table, the only place |
| `says so`, `said so` | "its documentation states this" |
| `a runner whose store's copy's name` | Name each thing in a separate sentence |
| `gone`, `a write gone late`, `went wrong` | a late write, a clock that gives a wrong value |
| `landed`, `lands whole` | is available, or nothing |
| `nothing else escapes`, `nothing of logex runs` | "logex returns no other error", "no part of logex runs" |
| `a mistake`, `the host's mistake` | an error in the source text, a wrong argument |
| `the edit takes the value across`, `the trip leaves each output at 0`: "lets", "leaves", "takes" or "gives" with a subject that is not a person or a part of logex | "The edit keeps the value of the tag." |
| A long sentence of clauses that commas and "and" join, with the verb at the end | Short sentences: subject, verb, object |
| `honest about it`, `said plainly`, `to be honest`, `in short`, `note that`: an opener or a closer that gives no fact | Nothing |
| `now`, `no longer`, `currently`, `today`, `not yet`, `so far` | The rule of the present only |
| `above`, `below`, `the following table`, `the next section` | A link to the section by its name, or "more than" and "less than" |
| A dash, a hyphen between 2 spaces, an arrow or a chain of semicolons in prose | Full stops |
| A plan label or the number of a decision in a user page | Nothing |

The checker refuses the literal forms of this table. It cannot find a different form of
the same manner. Read your page for the manner before you give it to a reviewer.

## An example

This text is from the README, before a writer changed it:

<!-- unchecked: a quotation of the older README, as an example of the manner -->
```text
A `var_input` is supplied from outside and no instruction may write it; a tag with no
initial value starts at 0. A timer, `var t1 ton`, is declared only with `var` and with no
initial value: its preset is the number on the `ton` that runs it.
```

The same rules, after:

- The host gives the value of a `var_input` tag. An instruction cannot write to it.
- A tag with no initial value starts at 0.
- Declare a timer with `var` only, and with no initial value. Example: `var t1 ton`.
- The `ton` instruction sets the preset of the timer.
