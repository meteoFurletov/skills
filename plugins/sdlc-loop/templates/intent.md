# Intent: <one line — what changes>

Author: <name>. Owner: <name>. Status: draft. Date: <YYYY-MM-DD>.

## Problem

<What is wrong now, in the originator's own words. Evidence, not adjectives.
Name things in the estate by their real names; name no code.>

## Outcome

<What is true once this ships. Not how.>

## Behaviours

<One line per behaviour the change must satisfy, in plain words. The design
transition turns these into Gherkin — no Given/When/Then here. More than about
eight lines, or more than one capability, is a programme: split it (see below).>

- <behaviour>

<For a change that expresses nothing in Given/When/Then — a refactor, a
dependency bump, performance work — delete the list and write exactly:
"No scenario changes. The existing scenarios must still pass.">

## Out of scope

- <what this deliberately does not do>

## Open questions

<What blocks the design. "None outstanding. Ready for design." when there are none.>

<!--
Status is one of: draft, accepted, split, parked, rejected.

A split intent keeps this file as the parent, sets `Status: split`, replaces
Behaviours with the ordered list of child changes, one line each:

## Children

1. `<NNN>-<slug>` — <the one capability it carries>

CURRENT never points at a split parent. A parked or rejected intent carries one
line under the status saying why, and nothing downstream is written.
-->
