FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libssl-dev \
      libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY Gemfile polymux.gemspec ./
COPY lib/polymux/version.rb lib/polymux/version.rb

RUN bundle install

COPY . .
