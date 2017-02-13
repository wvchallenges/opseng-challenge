# Wave Operations Engineering Development Challenge

This is my (Julien) submission for Wave ops challenge.

## What I have done

This project only consists in some shell scripts, I just wanted to keep it simple and be as efficient as possible.
I'm somewhat proud of acheiving this challenge because I had never used AWS until now. And I have also learned a lot of thing about Python web apps since it was also the first time I have to deploy this kind of things.

## How it works

Simply run aws-app.sh to deploy the app. There are also some parameters :

```bash
usage: ./aws-app.sh [-b|--branch-or-tag <branch-or-tag>][-h|--help]

-b|--branch-or-tag <branch-or-tag>  Sets the branch or tag name of the GitHub repository to deploy to AWS
-h|--help                           Prints this help message
```

## Some more info

I chose to use an Ubuntu EC2 instance because I use Debian-based distros every day, so I really feel comfortable using then.
It is the same for the Nginx server I used, I know it is a quite solid and easy to install solution when you need a reverse proxy to publish a web app.

## Improvements

Some things could be improved in what I have done:

- Use something like [RunIt](https://wiki.debian.org/runit) to manage Gunicorn deamon and to be sure it runs after the EC2 instance is restarted for instance
- Extract parameters from main shell script in order to store them in a Yaml file for instance, which is more user-friendly
- Store the opseng-challenge-app files in a S3 bucket and mount this storage from EC2 instance in order to be able to quickly scale up the system by adding some other EC2 instances sharing the same bucket.
- Use Route53 to define an easy to remember DNS name for the app
