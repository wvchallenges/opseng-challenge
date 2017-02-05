I started out by dockerizing the app mainly because Wave has been dockerizing their microservices so this would show my understanding of Docker.  As for the command which it runs, my initially edited the app.py file to pass host='0.0.0.0' argument to the app.run() function, but...because gunicorn was used in the original README, I decided to have it run gunicorn and bind it to 0.0.0.0:8000 at runtime instead. 

Reading about the EC2 Container Service, I knew that was what I wanted to use to implement my solution, however the Amazon tutorial YouTube videos are horribly outdated and wasn't much help so I had to do a lot of external digging and reading.  In the end I managed to get it working and am quite happy with the result.   

(My fallback plan was less elegant: create an EC2 RHEL7 server, install docker on there and run the container)
