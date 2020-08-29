git pull
hexo clean
hexo generate
git restore docs/_config.yml
git add .
git commit -m "commit"
git push