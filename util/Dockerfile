FROM registry.fedoraproject.org/fedora:38

RUN dnf install -y kubernetes-client && dnf clean all && rm -rf /var/cache/dnf
ENTRYPOINT /bin/bash
