#!/usr/bin/python2
# A basic hello world
# All my code is in python3 :(

from flask import Flask,request
app = Flask(__name__)

@app.route('/')
@app.route('/<path:path>/')
def main(path=None):
	domain = request.headers['Host']
	return("Welcome to {}!".format(domain))

if __name__ == '__main__':
	app.debug = True
	app.run(host='::')
