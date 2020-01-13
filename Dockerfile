FROM ruby:2.7-slim

WORKDIR /usr/src/app
COPY unassigned_maintenance.rb .

CMD ["./unassigned_maintenance.rb"]
