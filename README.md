# Wave OpsEng Development Challenge

Applicants for the [Operations Engineer career](https://www.waveapps.com/about-us/jobs/operations-engineer/) at Wave must complete the following challenge, and submit a solution prior to the interviewing process. This will help the interviewers assess your strengths, and frame the conversation through the interview process. Take as much time as you need, however we ask that you not spend more than 4-8 hours.

Send your submission to [ops.careers@waveapps.com](ops.careers@waveapps.com). Feel free to email [ops.careers@waveapps.com](ops.careers@waveapps.com) if you have any questions.

## Submission Instructions

1. Fork this project on github. You will need to create an account if you don't already have one
1. Complete the project as described below within your fork
1. Push all of your changes to your fork on github and submit a pull request.
1. You should also email [ops.careers@waveapps.com](ops.careers@waveapps.com) and your recruiter to let them know you have submitted a solution. Make sure to include your github username in your email (so we can match applicants with pull requests).

## Alternate Submission Instructions (if you don't want to publicize completing the challenge)

1. Clone the repository
1. Complete your project as described below within your local repository
1. Email a patch file to [ops.careers@waveapps.com](ops.careers@waveapps.com)

## Project Description

Imagine you’re starting a blog called Opsgadget. You’re going to be writing articles about the latest and greatest in IT operations. The first thing you decide to do is to make a very simple blog using Python and Flask. Your team of developers are going to be adding features to the blog. To help them speed their releases to Production, you also want to template and automate building an EC2 server. You do this by creating configuration formulas that your servers can use to automatically install the needed software to run Python and Flask, and pull the latest Flask application repo to the server.

First, create the Flask app. This is the easy part! There’s a [QuickStart Guide to working with Flask](http://flask.pocoo.org/docs/quickstart/). Just follow the directions, and don’t worry about making your blog any fancier than what’s described in that documentation; getting your blog to display “hello world” is fine.

While the developers are writing code, you want to allow them to deploy code themselves using Ansible. They should be able to deploy the blog app remotely using a combination of Ansible playbooks and/or command line tools (bash + aws cli).

In developing both the app and Ansible formulas, use GitHub and try to keep a decent history of how you approached the project.

**Here are the specs you want:**

* Instance Type: `t1.micro`
* OS: `Ubuntu Server 14.04 64-bit`
* App Server: `Gunicorn/Nginx`
* Python: `2.7`
* Flask: `0.10.1`

### Deliverables

1. A Github repo containing the flask app
1. A Github repo containing the Ansible playbooks (don’t check in the key/secret or pem file we give you).
1. A bash script called `aws-flask.sh` that will:
    * Launch the EC2 server using aws cli utilities
    * Begin the configuration management / bootstrapping of the server using an Ansible playbook

### Notes

* **Do not check AWS keys or any other secret credentials into Github**
* Remember to use security groups to restrict port access
* Prefix all of your AWS resources (when possible) with your first name (example: joanne.domain.com)
* I should be able to perform the following commands and then interact with a functioning app in my browser (you can assume we have the AWS Unified CLI installed):

```
$ git clone <your username>/<repo name>
$ cd <repo name>
$ ./aws-flask.sh

...

Flask application is running at http://<application ip>.
```

## Evaluation

Evaluation of your submission will be based on the following criteria.

1. Did your application fulfill the basic requirements?
1. Did you document the method for setting up and running your application?
1. Did you follow the instructions for submission?
