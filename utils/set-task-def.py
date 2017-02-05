#!/usr/bin/env python

from __future__ import print_function

import json
import sys

name = sys.argv[1]
image = sys.argv[2]
git_sha = sys.argv[3]

d = json.loads(sys.stdin.read())

d['containerDefinitions'][0]['name'] = name
d['containerDefinitions'][0]['image'] = image
d['containerDefinitions'][0]['dockerLabels']['git_sha'] = git_sha

print(json.dumps(d, indent=4))
