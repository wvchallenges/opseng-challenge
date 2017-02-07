#!/usr/bin/env python

from __future__ import print_function

import json
import sys

family = sys.argv[1]
name = sys.argv[2]
image = sys.argv[3]

d = json.loads(sys.stdin.read())

d['family'] = family
d['containerDefinitions'][0]['name'] = name
d['containerDefinitions'][0]['image'] = image

print(json.dumps(d, indent=4))
