<!-- sdlc-loop:begin -->
# Review policy

The review passes live in `.github/copilot-instructions.md`, where Copilot code
review applies them to every pull request and `/sdlc-loop:deploy` addresses what
it finds. Edit them there.

Production releases wait for a named approver. Install that gate with
`/sdlc-loop:init --gate`.
<!-- sdlc-loop:end -->
