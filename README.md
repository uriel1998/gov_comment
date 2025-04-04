# gov_comment

This script parses the Federal Register page, finds things that are requests for 
comment, gets a human-readable version of the actual issue (I don't consider 
legalese "human-readable") and outputs it both to an RSS feed and to a bot 
Mastodon account. 

You can follow it on [Mastodon](https://faithcollapsing.com/@USGovComment).

BlueSky will be via BridgyFed once it's more than a week old, lol.

The feed that is with the most recent requests posted is here [github](https://raw.githubusercontent.com/uriel1998/gov_comment/refs/heads/master/rss_output/gov_rfc_rss.xml) 

A feed with issues where the request for comment ends soon is in the works.

If you want to see the output as a web page, you can [here](https://ideatrash.net/us-government-requests-for-comment).


## Contents
 1. [About](#1-about)
 2. [License](#2-license)
 
 ***

## 1. About

TL;DR: The feds make lots of data available, but actually parsing/skimming it is a pain. 
I won't say that's on *purpose*, but... 

...anyway, this is a small effort to help make clear where your voice is requested and can make a difference.

After the script runs, there's a git commit and push to github. 

A large chunk of this is adapted from [agaetr](https://github.com/uriel1998/agaetr). Honestly, you probably want to use that or the feed link above.

## 2. License

This project is licensed under the MIT License. For the full license, see `LICENSE`.
