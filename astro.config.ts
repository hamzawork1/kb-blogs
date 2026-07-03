import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";
import expressiveCode from "astro-expressive-code";
import remarkGfm from "remark-gfm";
import spectre from "./package/src";
import { spectreDark } from "./src/ec-theme";

// Giscus env vars kept for future enable — uncomment block below when ready.
// import { loadEnv } from "vite";
// import type { GiscusMapping } from "./package/src";
// const {
// 	GISCUS_REPO,
// 	GISCUS_REPO_ID,
// 	GISCUS_CATEGORY,
// 	GISCUS_CATEGORY_ID,
// 	GISCUS_MAPPING,
// 	GISCUS_STRICT,
// 	GISCUS_REACTIONS_ENABLED,
// 	GISCUS_EMIT_METADATA,
// 	GISCUS_LANG,
// } = loadEnv(process.env.NODE_ENV!, process.cwd(), "");

// https://astro.build/config
const config = defineConfig({
	site: "https://blog.mhamza.space",
	output: "static",
	// astro-expressive-code registers its own markdown.remarkPlugins entry,
	// which makes Astro skip its built-in GFM (tables, strikethrough, task
	// lists) support unless we re-add it explicitly here.
	markdown: {
		remarkPlugins: [remarkGfm],
	},
	integrations: [
		expressiveCode({
			themes: [spectreDark],
		}),
		mdx(),
		sitemap(),
		spectre({
			name: "Muhammad Hamza",
			openGraph: {
				home: {
					title: "Muhammad Hamza",
					description:
						"Azure Cloud Specialist & Azure DevOps Engineer — notes, projects, and field-tested guides on cloud, DevOps, and platform engineering.",
				},
				blog: {
					title: "Blog",
					description:
						"Writing on Azure, DevOps, CI/CD, IaC, and platform engineering.",
				},
				projects: {
					title: "Projects",
					description: "Selected work and side projects.",
				},
			},
			giscus: false,
			// giscus: {
			// 	repository: GISCUS_REPO,
			// 	repositoryId: GISCUS_REPO_ID,
			// 	category: GISCUS_CATEGORY,
			// 	categoryId: GISCUS_CATEGORY_ID,
			// 	mapping: GISCUS_MAPPING as GiscusMapping,
			// 	strict: GISCUS_STRICT === "true",
			// 	reactionsEnabled: GISCUS_REACTIONS_ENABLED === "true",
			// 	emitMetadata: GISCUS_EMIT_METADATA === "true",
			// 	lang: GISCUS_LANG,
			// },
		}),
	],
	// Node adapter removed for static-only deploys (Cloudflare Pages / GitHub Pages / etc.).
	// If you ever need SSR, reinstall @astrojs/node and re-add `adapter: node({ mode: "standalone" })`.
});

export default config;
