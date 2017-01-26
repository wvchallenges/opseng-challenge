In order to not over complicate things and somehow shoot myself in the foot for this challenge, I decided to stick with mostly what I knew best/comfortable with:

I started out by dockerizing the app mainly because Wave has been dockerizing their microservices so this would show my understanding of Docker.  As for the command which it runs, my initially edited the app.py file to pass host='0.0.0.0' argument to the app.run() function, but...because gunicorn was used in the original README, I decided to have it run gunicorn and bind it to 0.0.0.0:8000 at runtime instead. 

I then decided I would run this on an EC2 RHEL7 node -- although it 
