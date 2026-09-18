.PHONY: setup destroy build deploy verify monitor test lint

setup:
	chmod +x scripts/*.sh
	./scripts/setup-infra.sh $(GITHUB_REPO)

destroy:
	./scripts/destroy-infra.sh

build:
	./scripts/build.sh

deploy:
	./scripts/deploy.sh

verify:
	./scripts/verify-infra.sh

monitor:
	./monitoring/prometheus/install.sh
	./monitoring/grafana/install.sh

test:
	pytest

lint:
	terraform fmt -check -recursive terraform/
