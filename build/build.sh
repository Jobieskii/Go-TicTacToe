#!/bin/bash
cd frontend
zip -r frontend-v1.zip .* *
mv frontend-v1.zip ../
cd ../backend
zip -r backend-v1.zip .* *
mv backend-v1.zip ../

# https://user3148951frontend.us-east-1.elasticbeanstalk.com/login.html?code=20f9145b-ee11-49a4-badf-cc0572c8a24a