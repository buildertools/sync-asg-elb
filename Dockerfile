FROM debian:jessie
RUN apt-get update && \
    apt-get install -y ca-certificates python-pip jq && \
    pip install awscli
ENTRYPOINT ["/bin/bash", "-c"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["pgrep","sync-asg-elb"]
COPY ./sync-asg-elb.sh /bin/sync-asg-elb.sh
