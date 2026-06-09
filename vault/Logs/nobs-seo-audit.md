---
title: "Log: nobs-seo-audit"
updated: 2026-06-02T01:27:12+00:00
tags: [system, logs, autopilot]
---
# nobs-seo-audit.service Loop Activity

```text
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
- ⚠️ Page speed score: 78/100 (optimize images, defer non-critical CSS).  

DONE
Error response from daemon: container df56278049adbd473b5c7f2fcdf49c85ea102c2981c0e99b0114cdd7d5380e45 is not running
Traceback (most recent call last):
  File "/home/alex/bin/discord-ctl", line 101, in <module>
    main()
    ~~~~^^
  File "/home/alex/bin/discord-ctl", line 70, in main
    cid = resolve(a.channel)
  File "/home/alex/bin/discord-ctl", line 49, in resolve
    for c in channels():
             ~~~~~~~~^^
  File "/home/alex/bin/discord-ctl", line 44, in channels
    return req("GET", "/guilds/%s/channels" % GUILD)
  File "/home/alex/bin/discord-ctl", line 32, in req
    "Authorization": "Bot " + token(),
                              ~~~~~^^
  File "/home/alex/bin/discord-ctl", line 25, in token
    return subprocess.check_output(
           ~~~~~~~~~~~~~~~~~~~~~~~^
        ["docker", "exec", "nobs-discord-bot", "printenv", "DISCORD_TOKEN"]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ).decode().strip()
    ^
  File "/usr/lib/python3.14/subprocess.py", line 473, in check_output
    return run(*popenargs, stdout=PIPE, timeout=timeout, check=True,
           ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
               **kwargs).stdout
               ^^^^^^^^^
  File "/usr/lib/python3.14/subprocess.py", line 578, in run
    raise CalledProcessError(retcode, process.args,
                             output=stdout, stderr=stderr)
subprocess.CalledProcessError: Command '['docker', 'exec', 'nobs-discord-bot', 'printenv', 'DISCORD_TOKEN']' returned non-zero exit status 1.
```
