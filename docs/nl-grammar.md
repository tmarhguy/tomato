# Envelop controlled natural language

Envelop implements a small controlled natural language that compiles into
Tomato IR. It is deterministic: identical input and identical Envelope
version always generate the exact same Tomato program. There is no LLM
anywhere in this path, by design.

Pipeline: shell strip → phrase normalizer → function-call expansion →
word operators → gate → lex → grammar (AST) → semantic validator →
register allocation → Tomato IR (bytecode v1).

## Token classes

Only grammatical filler may be discarded. Unknown is never discarded.

- VALUE: integers (`93`, `0x59`, `0b101`), registers (`R0`–`R7`)
- OPERATOR: `+ - & | ^ ~`, words (`plus`, `minus`, `and`, `or`, `xor`),
  aliases `sum`/`add` → plus, `difference`/`subtract` → minus;
  `OP of/between A and/with B[, C…]` → `OP(A, B[, C])`;
  calls: `plus/minus/and/or/xor/nand/nor/xnor(a, b[, ...up to 8])`
  left-folded (`nand`/`nor`/`xnor` negate with `~`, no single-cycle XNOR
  in hardware so lowering is exact); `not(a)`; single-cycle direct
  (dual-LUT→adder / masked ALU, bytecode 7–13):
  `maskadd/xorand/andadd/oradd/xoradd(a, b, c)`, `andn/orn(a, b)`
- FILLER (boundaries only, never mid-expression): leading shells (below);
  trailing `on/for/from Tomato`, `for me`, `thank you`, `thanks`,
  `please`, `equal`/`equals`; articles `the`/`a`/`an` as whole words;
  `of`/`between`/`with` only inside an approved `OP of A and B` list
- UNKNOWN: anything else (`squared`, `bananas`, …) → reject, never guess;
  a unique recovery may add `Did you mean …?` to the error

## Sentence shells (longest-match-first, case-insensitive)

`could you please` · `would you please` · `can you please` ·
`can tomato calculate` · `can tomato compute` ·
`what does` · `what is` · `what's`/`whats` · `how much is` ·
`tell me`/`give me`/`show me` (optional `the`) · `work out` ·
`figure out` · `can you` · `could you` · `would you` ·
`the result/value/answer of` · `calculate` · `compute` ·
`evaluate` · `please` · `hey/hi/hello` (greeting + comma only,
e.g. `Hey Tomato, …`) · leading `on/for/from Tomato,` (comma
required, e.g. `on tomato, what is …`).
A bare `hello tomato` (no comma) stays a greeting and is never compiled.

All shells reduce to `COMPUTE(<expr>)`. `/run` programs bypass the
grammar entirely and go straight to the ISA assembler, plus Phase-1
aliases (same bytes, no new opcodes): `LD/LI Rd, imm` → `Rd=imm`
(`ld r0 8` → `R0=8`); `LD Rd, [off]` → `LOAD`; `ST [off], Rs` →
`STORE`; `MOV Rd, Rs` → `OR Rd,Rs,Rs`; `CLR Rd` → `Rd=0`.

## Phrase constructions (`OP of …`)

Approved English argument lists rewrite before function expansion.
`and` / `with` / commas are separators here, not bitwise AND:

```
xor of 5 and 3          → xor(5, 3)
the xor of 5 and 3
xor between 6 and 3
xor of 5 with 3
xor of 1 and 2 and 3    → xor(1, 2, 3)
not of 5                → not(5)
sum of 2 and 3          → plus(2, 3)
difference of 10 and 3  → minus(10, 3)
```

`product of` / `times of` lower to `*` and still fail closed
(`ERR UNSUPPORTED_OP`); multiplication is not installed.

Unknown words are never dropped. A unique one-edit operator name
(`xorr` → xor) or a digit-free prefix in front of a compiling
phrase (`whqa it xor of 5 and 3`) yields a fail-closed
`Did you mean …?` — the guess is never executed.

## Expression grammar and precedence

```
expr       := or
or         := xor ("|" xor)*
xor        := and ("^" and)*
and        := sum ("&" sum)*
sum        := unary (("+" | "-") unary)*
unary      := ("~" | "-") unary | primary
primary    := INTEGER | REGISTER | "(" expr ")"
call       := NAME "(" expr ("," expr){1,7} ")"   # NAME in plus..xor,nand,nor,xnor, binds tight
             | "not" "(" expr ")"                       # exactly one
             | ("andn"|"orn") "(" expr "," expr ")"      # exactly two
             | ("maskadd"|"andadd"|"oradd"|"xoradd"|"xorand") "(" expr "," expr "," expr ")"
# f(a,b,c) + g(a,b,c) + h(...) chains: each call folds left, then combines
# with + - & | ^ as usual, e.g. and(83,456,34) + nand(45,34,3),
# xnor(1,2,3) + not(4), maskadd(1,2,3) + xorand(1,2,3).
```

`*`, `/`, `%` lex but fail closed at validation: multiplication and
division are not installed (`ERR UNSUPPORTED_OP`). Bare registers read
the job's private registers (zero-initialized); user registers are
reserved before allocation and never written (copied on use).

## Allocation order (both implementations, identical)

Free pool `R7…R0` minus reserved registers, allocate lowest first;
right operand freed after each op (never a reserved register);
`~x` lowers to `XOR x,x,0xFFFFFFFF`. Canonical output is byte-identical
between `tools/remote_compile.py` and the browser `compiler.mjs`.

## Understood line

Each compute result carries `understood`: the AST reprinted with
non-atomic children always parenthesized (unambiguous by construction),
original literal spellings kept (`0xFF` stays `0xFF`). The chat card
shows it as a one-line provenance field; full program and bytes live
behind View execution.

## Fixtures

`tools/nl_fixtures.json` is the contract both suites consume:
recognized shell + valid expression + approved filler → compile;
unknown in semantic position → reject naming the word; unsupported
op → reject naming the op; ambiguous adjacency → reject. Never best-guess.
v2 (variadic + nand/nor): 27 compute / 4 chat / 7 error cases; arity is
two-to-eight (`ERR FN_ARITY`), single-arg and nine-arg calls reject.
v3 (growth, no firmware): 35 compute / 4 chat / 10 error;
`xnor/not` lowered; `/run` aliases `LD/LI/ST/MOV/CLR`.
v4 (direct dual-LUT): 37 compute / 4 chat / 10 error;
`maskadd/xorand/andadd/oradd/xoradd/andn/orn` emit single-cycle
bytecode 7–13 (`remote_exec.s`), no intermediates.
v5 (English `OP of`): 51 compute / 4 chat / 14 error;
`xor of 5 and 3` and shells (`what's`, `tell me`, `how much is`);
fail-closed `Did you mean`; chat fixtures `tell me about tomato`
and `what is the time on tomato` stay chat.
