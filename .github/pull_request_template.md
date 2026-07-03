<!--
Keep this short. Reviewers (and future-you) skim PRs — describe the change,
its intent, and how you verified it. No task log, no "what I tried".
-->

## What

<!-- 1-2 sentences. Behaviour change, not implementation noise. -->

## Why

<!-- Link the issue / ADR / decision. If none exists, write the motivation here. -->

## How verified

- [ ] `pnpm lint` passes
- [ ] `pnpm check` passes
- [ ] `pnpm build` produces a working `dist/`
- [ ] Manually exercised on `staging.mhamza.space` (if a deploy-affecting change)

## Risk / rollback

<!-- What could break, how to revert. Usually: `git revert` + redeploy. -->
