---
title: "Log: nobs-content-ideas"
updated: 2026-06-02T01:27:12+00:00
tags: [system, logs, autopilot]
---
# nobs-content-ideas.service Loop Activity

```text
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
2026-06-02T00:03:32+00:00 generating content ideas
Wrote 12 items to /home/alex/logs/rss-latest.md
# 💡 Content Ideas 2026-06-02  
1. **"Apple’s privacy update? We’ve been doing this for years."** – Angle: NOBS’s owner-operated infrastructure aligns with Apple’s new privacy-first mandates, proving private AI isn’t a niche hack.  
2. **"Edge computing isn’t a trend — it’s the only way forward."** – Angle: As edge adoption surges, NOBS’s pre-configured edge nodes let you skip the hype and deploy instantly.  
3. **"AI tools are useless without owner control. Here’s how we fix that."** – Angle: New developer AI kits miss the point — NOBS’s managed hosting lets you own every decision, every layer.  

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
