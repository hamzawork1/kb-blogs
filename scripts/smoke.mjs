#!/usr/bin/env node
// Post-deploy synthetic smoke test. Hits the deployed URL, asserts HTTP 200,
// and verifies the response body contains markers proving it's the real site.
//
// Usage:   node scripts/smoke.mjs <url>
// Exit 0:  All markers present.
// Exit 1:  Wrong status code or missing marker.
//
// Run from CI immediately after a successful Wrangler deploy. Catches the
// "deploy succeeded but the site is broken" failure mode (Cloudflare cache
// poisoning, asset manifest mismatch, 404 on root, etc.).

const url = process.argv[2];

if (!url) {
	console.error("Usage: node scripts/smoke.mjs <url>");
	process.exit(2);
}

const res = await fetch(url, { redirect: "follow" });

if (res.status !== 200) {
	console.error(`FAIL: ${url} returned HTTP ${res.status}`);
	process.exit(1);
}

const body = await res.text();

// Markers: site-specific strings that prove the rendered page is ours.
// Astro injects the generator meta tag automatically; the site name comes
// from spectre({ name: "Muhammad Hamza" }) in astro.config.ts.
const markers = ["Muhammad Hamza", '<meta name="generator" content="Astro'];

const missing = markers.filter((m) => !body.includes(m));
if (missing.length > 0) {
	console.error(`FAIL: ${url} missing markers: ${missing.join(", ")}`);
	process.exit(1);
}

console.log(`OK  ${url}  (${body.length} bytes, all markers present)`);
