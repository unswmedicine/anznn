#!/bin/bash
docker-compose exec web bundle exec rspec && \
docker-compose exec web bundle exec cucumber
