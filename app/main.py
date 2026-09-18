"""
Minimal placeholder app for the AI-platform-infra pipeline demo.

This project is about the INFRA (Terraform, EKS, IAM, CI/CD) - not about
this app. It exists only so the Docker build / ECR push / Kubernetes
deploy / rollout-status steps have something real to build, push, and run
end to end. Swap this for any real containerized workload without
touching the rest of the pipeline.
"""
from fastapi import FastAPI

app = FastAPI(title="sample-app")


@app.get("/")
def root():
    return {"status": "ok", "service": "sample-app"}


@app.get("/health")
def health():
    return {"status": "healthy"}
