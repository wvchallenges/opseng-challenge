# Wave Operations Engineering Development Challenge

Applicants for the [Operations Engineering team](https://jobs.lever.co/waveapps) at Wave must complete the following challenge, and submit a solution prior to the interviewing process. 

The purpose of this exercise is to create something that we can discuss during the on-site interview, and that's representative of the kind of things we do here on a daily basis.

There isn't a hard deadline for this exercise; take as long as you need to complete it. However, in terms of total time spent actively working on the challenge, we ask that you not spend more than a few hours, as we value your time and expect to leave things open to discussion in the on-site interview.

Send your completed submission to your contact at Wave. Feel free to email [ops.careers@waveapps.com](ops.careers@waveapps.com) if you have any questions.

## Submission Instructions

1. Fork this project on GitHub -  you'll need to create an account if you don't already have one
1. Complete the project as described below within your fork
1. Push all of your changes to your fork on GitHub and submit a pull request
1. Email your contact at Wave to let them know you have submitted a solution, and make sure to include your GitHub username in your email (so we can match applicants with pull requests)

## Alternate Submission Instructions (if you don't want to publicize completing the challenge)

1. Clone the repository
1. Complete your project as described below within your local repository
1. Email a patch file to your contact at Wave

## Project Description

There's a basic Python app available [here](https://github.com/wvchallenges/opseng-challenge-app). Your task is to host this app on AWS, using the current `HEAD` of the `master` branch as of when we test your submission.

The OS used for hosting, and the tools & techniques used to accomplish this are up to you. Once you're done, please submit a paragraph or two in your `README` about what you're particularly proud of in your implementation, and why. Be deliberate in your choices and design, as we'll use them as a starting point for our discussions.   

### Deliverables

You should provide at least an executable bash script called `aws-app.sh`. You're welcome to include other files and install/use other tools in your repo as needed, but `aws-app.sh` is what we'll run to test your submission (see the evaluation section).

#### Notes

* **Do not check AWS keys or any other secret credentials into git**
* Prefix all of your AWS resources (when possible) with your first name (example: joanne.domain.com)

## Evaluation

We'll do the following, using on a stock OSX machine with Python 3.9 or higher, the `awscli` Python package installed, and appropriate AWS environment variables set:
```
$ git clone <your username>/<repo name>  # Or we'll apply your patch file to a checked-out branch
$ cd <repo name>
$ ./aws-app.sh
```
We expect that this will output a URL, and we'll then visit that URL to confirm it has the output generated by the current `HEAD` of the `master` branch of the repo linked to above. 

When we're evaluating your submission, some of the questions we'll be asking are:

* If we follow the steps above, do we end up with a working app at the URL specified?
* Does the working app reflect what's at the `HEAD` of the `master` branch right now, or at a point in the past? 
* If we wanted to push out an updated version of the app's code, how much work would that be? 
* Which application(s) and OS were chosen to host the app, and why?
* Which hosting strategy was selected, and did you have a good reason to pick that one?
* Are the decisions and strengths/weaknesses of this strategy discussed?
* How much of the hosting infrastructure is created when calling `aws-app.sh`, and how much does the script assume already exists or is created by hand in the console?

