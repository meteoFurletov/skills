# Owner: <name>. From: spec.md R<n>.
# Scenarios are the contract. They change at the spec transition, not during
# Build — a hook blocks edits to this file.

Feature: <the capability, not the implementation>

  Scenario: <the behaviour, in the originator's words>
    Given <the world before>
    When <the one action>
    Then <the observable result>
