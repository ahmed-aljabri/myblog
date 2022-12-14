#!/bin/sh

# If a command fails then the deploy stops
set -e

# Just a tooltip to let you know the script is running.
printf "\033[0;32mDeploying updates to GitHub...\033[0m\n" 

# Build the hugo site to both of your repos
hugo
hugo -d public/ # This builds the public site into your public repo. !!!!! Make sure to replace with your currect public repo here

# Deploy your public site
cd public/ # Goes to your public site repo
git init # Initiatilizes git
git add . # Adds changes

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi

git commit -m "$msg" # Makes your commit with the message from your deploy script execution
git push origin main # Pushes the code to GitHub

# Now deploy your backend with all of the 
cd ../remoteblog #!!!!! Make sure to replace with your currect backend repo here.
git add . # Adds changes

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi

git commit -m "$msg" # Makes your commit with the message from your deploy script execution
git push origin main # Pushes the code to GitHub