---
title: "Log: nobs-blog-draft"
updated: 2026-06-02T01:27:12+00:00
tags: [system, logs, autopilot]
---
# nobs-blog-draft.service Loop Activity

```text
2026-06-01T03:20:12+00:00 writing blog draft
Wrote 20 items to /home/alex/logs/rss-week.md
GatewayClientRequestError: FailoverError: ⚠️ litellm-tank (tier/cheap) returned a billing error — your API key has run out of credits or has an insufficient balance. Check your litellm-tank billing dashboard and top up or switch to a different API key.
posted to drafts
2026-06-01T03:20:18+00:00 posted draft to #drafts
2026-06-01T04:32:42+00:00 writing blog draft
Wrote 20 items to /home/alex/logs/rss-week.md
GatewayClientRequestError: FailoverError: ⚠️ litellm-tank (tier/cheap) returned a billing error — your API key has run out of credits or has an insufficient balance. Check your litellm-tank billing dashboard and top up or switch to a different API key.
posted to drafts
2026-06-01T04:32:48+00:00 posted draft to #drafts
2026-06-01T05:06:42+00:00 writing blog draft
Wrote 20 items to /home/alex/logs/rss-week.md
GatewayClientRequestError: Error: Model override "litellm-tank/tier/local-heavy" is not allowed for agent "main".
posted to drafts
2026-06-01T05:06:48+00:00 posted draft to #drafts
2026-06-01T15:13:13+00:00 writing blog draft
Wrote 20 items to /home/alex/logs/rss-week.md
posted to drafts
2026-06-01T15:23:19+00:00 posted draft to #drafts
2026-06-01T16:10:08+00:00 writing blog draft
Wrote 20 items to /home/alex/logs/rss-week.md
# NOBS SEO Audit 2026-06-01  

**Critical Issues**  
- ❌ Missing `<meta name="description">` on `/agency/index.html`, `/research/index.html`, and `/cli/index.html` (3 pages).  
- ❌ Inconsistent `<h1>` usage: 2 pages use duplicate titles, 1 page lacks an `<h1>`.  
- ❌ Missing Open Graph tags on `/privacy.html` and `/dev.html` (no `og:title`, `og:description`, or `og:image`).  
- ❌ 3 broken internal links detected (`/brain/index.html`, `/dash.html#features`, `/agency/contact`).  

**Opportunities**  
- ✅ Alt text missing on 5 images (e.g., `/dash.html` hero image, `/privacy.html` logo).  
- ✅ Schema markup incomplete: missing `Organization` and `WebPage` types.  
- ✅ Internal linking could be improved—add 2–3 contextual links per page to related content.  

**Technical**  
- ✅ Mobile-friendly (passed Google Mobile-Friendly Test).  
- ✅ No crawl errors detected (sitemap valid, robots.txt clear).  
- ⚠️ Page speed score: 78/10线 (optimize images, defer non-critical CSS).  

DONE
posted to drafts
2026-06-01T16:16:20+00:00 posted draft to #drafts
```
