// commitlint config consumed by wagoid/commitlint-github-action in ci.yml.
//
// Extends @commitlint/config-conventional, which enforces Conventional
// Commits (https://www.conventionalcommits.org/). The allowed types match
// what this repo has been using consistently in commit history.

export default {
	extends: ["@commitlint/config-conventional"],
	rules: {
		"type-enum": [
			2,
			"always",
			[
				"feat", // new feature on the live site or tooling
				"fix", // bug fix
				"docs", // documentation only
				"ci", // CI/CD pipeline changes
				"chore", // repo maintenance, deps, metadata
				"refactor", // code structure changes, no behaviour change
				"perf", // performance improvement
				"style", // formatting only
				"test", // tests only
				"post", // new blog post (project-specific)
				"revert", // reverting a previous commit
				"build", // build system or external deps
			],
		],
		"subject-case": [0], // allow any case (titles often have proper nouns)
		"body-max-line-length": [0], // long URLs and prose blocks happen
	},
};
