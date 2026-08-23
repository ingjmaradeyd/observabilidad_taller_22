FROM public.ecr.aws/aws-observability/aws-otel-collector:latest
COPY otel-collector-config-aws.yaml /etc/otel/otel-collector-config.yaml
CMD ["--config=/etc/otel/otel-collector-config.yaml"]