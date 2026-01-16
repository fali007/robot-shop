.PHONY: build push
IMAGE_REPO := quay.io/agentbench
TAG := latest

# Individual Service Builds

build:
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-cart:$(TAG) cart/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-catalogue:$(TAG) catalogue/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-dispatch:$(TAG) dispatch/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-payment:$(TAG) payment/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-ratings:$(TAG) ratings/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-shipping:$(TAG) shipping/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-user:$(TAG) user/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-web:$(TAG) web/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-mongodb:$(TAG) mongo/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-mysql-db:$(TAG) mysql/

push:
	docker push $(IMAGE_REPO)/rs-cart:$(TAG)
	docker push $(IMAGE_REPO)/rs-catalogue:$(TAG)
	docker push $(IMAGE_REPO)/rs-dispatch:$(TAG)
	docker push $(IMAGE_REPO)/rs-payment:$(TAG)
	docker push $(IMAGE_REPO)/rs-ratings:$(TAG)
	docker push $(IMAGE_REPO)/rs-shipping:$(TAG)
	docker push $(IMAGE_REPO)/rs-user:$(TAG)
	docker push $(IMAGE_REPO)/rs-web:$(TAG)
	docker push $(IMAGE_REPO)/rs-mongodb:$(TAG)
	docker push $(IMAGE_REPO)/rs-mysql-db:$(TAG)
